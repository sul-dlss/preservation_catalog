# frozen_string_literal: true

require 'open3'

module Replication
  # For replication purposes, we may have to chunk archival objects (zips) of Moab versions into multiple files to avoid
  #   unwieldy file sizes.  This model is for interaction with the entire multi-part zip;
  #   see DruidVersionZipPart for individual parts; note that all zips will have at least one part.
  # See comment on part_paths method re: individual part suffixes.
  # Just a regular model, not an ActiveRecord-backed model
  class DruidVersionZip
    attr_reader :druid, :version, :storage_location

    delegate :base64digest, :hexdigest, to: :md5

    # the size used with "zip -s" to break up the zip into parts
    ZIP_SPLIT_SIZE = '10g'

    # @param [String] druid
    # @param [Integer] version
    # @param [String] storage_location The path of storage_root/storage_trunk with the druid tree from which the zipped version should be
    #  created.  if nil, zip creation raises an error.
    def initialize(druid, version, storage_location = nil)
      @druid = DruidTools::Druid.new(druid.downcase, storage_location)
      @version = version
      @storage_location = storage_location
    end

    # @return [String] Filename/key without extension, in common to all this object's zip parts
    def base_key
      @base_key ||= s3_key.sub(/.zip\z/, '')
    end

    # Checks to see whether a zip file already exists for this druid-version.  If it does, just touch the
    # file to refresh atime and mtime, so the zip cache cleaning cron job doesn't see it as stale.  If it doesn't,
    # create it.
    # @raise [StandardError] if there's a zip file for this druid-version, but it looks too small to be complete.
    def find_or_create_zip!
      if exist?
        raise "zip already exists, but size (#{total_part_size}) is smaller than the moab version size (#{moab_version_size})!" unless zip_size_ok?
        FileUtils.touch(file_path)
      else
        create_zip!
      end
    end

    def exist?
      File.exist?(file_path)
    end

    # @return [Boolean] true if there is a match between the zip part files and their md5 sidecar files
    def complete?
      # There is at least one part file
      return false if part_paths.empty?
      # The set of md5 sidecar files matches the set of part files
      return false unless part_keys.to_set == part_keys_from_md5_sidecars.to_set
      # Check each md5 sidecar file against the zip part file
      druid_version_zip_parts.all?(&:md5_match?)
    end

    # Creates a zip of Druid-Version content.
    # Changes directory so that the storage root (and druid tree) are not part of
    # the archival directory structure, just the object, e.g. starting at 'ab123cd4567/...' directory,
    # not 'ab/123/cd/4567/ab123cd4567/...'
    def create_zip!
      check_moab_version_readability!
      ensure_zip_directory!
      combined, status = Open3.capture2e(zip_command, chdir: work_dir.to_s)
      raise "zipmaker failure #{combined}" unless status.success?
      unless zip_size_ok?
        raise "zip size (#{total_part_size}) is smaller than the moab version size (#{moab_version_size})! zipmaker failure #{combined}"
      end

      part_keys.each do |part_key|
        Replication::DruidVersionZipPart.new(self, part_key).write_md5
      end
    rescue StandardError
      cleanup_zip_parts!
      raise
    end

    # Ensure the directory the zip will live in exists
    # @return [Pathname] the existing or created directory
    def ensure_zip_directory!
      Pathname.new(file_path).tap { |pn| pn.dirname.mkpath }
    end

    # @param [Integer] count Number of parts
    # @return [Array<String>] Ordered pathnames expected to correspond to a zip broken into a given number of parts
    def expected_part_keys(count = 1)
      raise ArgumentError, "count (#{count}) must be >= 1" if count < 1
      [s3_key].concat(
        (1..(count - 1)).map { |n| base_key + format('.z%02d', n) }
      )
    end

    # @param [String] suffix, e.g. '.zip', '.z01', '.z125', etc., including the dot
    # @return [String] s3_key for the zip part specified by suffix
    # @see [S3 key name performance implications] https://docs.aws.amazon.com/AmazonS3/latest/dev/request-rate-perf-considerations.html
    # @example return 'ab/123/cd/4567/ab123cd4567.v0001.zip'
    def s3_key(suffix = '.zip')
      druid.tree.join('/') + ".#{v_version}#{suffix}"
    end

    # @return [String] Path to the local temporary transfer root (.zip) part
    def file_path
      File.join(zip_storage, s3_key)
    end

    # WITHOUT (re)digesting the file, convert a hexdigest MD5 value to base64-endcoded equivalent.
    # Motivation: we store hexdigest and S3 requires base64 in headers.
    # @param [String] hex
    # @return [String] base64 equivalent
    def hex_to_base64(hex)
      [[hex].pack('H*')].pack('m0')
    end

    # @raise [StandardError] if storage_location is not available (should have been provided in constructor)
    def moab_version_path
      raise "cannot determine moab_version_path for #{druid.id} v#{version}, storage_location not provided" unless storage_location
      @moab_version_path ||= "#{druid.path}/#{v_version}"
    end

    # @return [Array<String>] relative paths, i.e. s3_part_keys for existing parts
    def part_keys
      part_paths.map { |part| part.relative_path_from(zip_storage).to_s }
    end

    # NOTE: if there is only ONE part, it will end .zip;  if there are multiple parts,
    #  the last one will end .zip, so two parts is:  .z01, zip. (this agrees with zip utility)
    # @return [Array<Pathname>] Existing pathnames for zip parts based on glob (.zip, .z01, .z02, etc.)
    def part_paths
      Pathname.glob(file_path.sub(/.zip\z/, '.z*')).reject do |path|
        path.to_s =~ /.md5\z/
      end
    end

    # @return [Array<Pathname>] all extant zip part and checksum files for this dvz (e.g. bc123df4567.zip, bc123df4567.z01, bc123df4567.zip.md5,
    #  bc123df4567.z01.md5, etc)
    def parts_and_checksums_paths
      Pathname.glob(File.join(zip_storage, s3_key('.*')))
    end

    # @return [String] "v" with zero-padded 4-digit version, e.g., v0001
    def v_version
      format('v%04d', version)
    end

    # @return [Pathname] The proper directory in which to execute zip_command
    # @raise [StandardError] if storage_location is not available (should have been provided in constructor)
    def work_dir
      Pathname.new(moab_version_path).parent.parent
    end

    # @return [String] shell command to unzip
    # def unzip_command
    #   "unzip #{file_path} -d #{place_to_unzip}"
    # end

    # Presumes execution just "above" the druid dir in the druid tree, i.e. if the Moab is:
    #   /storage_trunk_01/bj/102/hs/9687/bj102hs9687/v0003/...
    # This command should execute from:
    #   /storage_trunk_01/bj/102/hs/9687/
    # @see #work_dir
    # @return [String] shell command to create this zip
    def zip_command
      "zip -r0X -s #{ZIP_SPLIT_SIZE} #{file_path} #{druid.id}/#{v_version}"
    end

    def zip_version
      @zip_version ||= fetch_zip_version
    end

    # @return [Pathname]
    def zip_storage
      @zip_storage ||= Pathname.new(Settings.zip_storage)
    end

    # This assumes that the zip file will be at least as large as the Moab version being zipped. Why? Because
    # we don't enable compression (see zip_command). Why no compression? We thought it might make extraction
    # from zips more reliable in the distant future. For further explanation, see https://github.com/sul-dlss/preservation_catalog/wiki/Zip-Creation
    def zip_size_ok?
      total_part_size > moab_version_size
    end

    def moab_version_size
      moab_version_files.sum { |f| File.size(f) }
    end

    # Deletes all zip part files and their md5 sidecar files from local zip storage
    def cleanup_zip_parts!
      FileUtils.rm_f(parts_and_checksums_paths)
    end

    # @return [Array<DruidVersionZipPart>] all parts for this DruidVersionZip
    def druid_version_zip_parts
      part_keys.map do |part_key|
        Replication::DruidVersionZipPart.new(self, part_key)
      end
    end

    private

    # Throws an error if any of the files in the moab are not yet readable.  For example due to
    # Ceph MDS instance for a pres cat worker VM thinking that a file is a stray as a result of our
    # particular use of hardlinking in preservation ingest.  Allows for a quick directory walk before
    # attempting to create the zip file(s).  See https://github.com/sul-dlss/preservation_catalog/issues/1633
    # @raise [StandardError] if storage_location is not available (should have been provided in constructor)
    # @raise [Errno::EACCES, Errno::EIO, Errno::ENOENT, Errno::ESTALE, ?] if it is not possible to stat one or more files in the Moab
    def check_moab_version_readability!
      moab_version_files.map { |f| File.stat(f) }
    end

    def total_part_size
      part_paths.sum { |part_path| File.size(part_path) }
    end

    def moab_version_files
      raise "Moab version does not exist: #{moab_version_path}" unless File.exist?(moab_version_path)
      Dir
        .glob("#{moab_version_path}/**/*")
        .select { |path| File.file?(path) }
    end

    # @return [String] e.g. 'Zip 3.0 (July 5th 2008)' or 'Zip 3.0.1'
    def fetch_zip_version
      match = nil
      IO.popen('zip -v') do |io|
        re = zip_version_regexp
        io.find { |line| match = line.match(re) }
      end
      return match[1] if match && match[1].present?
      raise 'No version info matched from `zip -v` ouptut'
    end

    def zip_version_regexp
      /This is (Zip \d+(\.\d)+\s*(\(.*\d{4}\))?)/
    end

    # @return [Array<String>] relative paths, i.e. s3_part_keys for existing parts based on the md5 sidecar files
    def part_keys_from_md5_sidecars
      md5_sidecar_paths.map { |md5_path| md5_path.relative_path_from(zip_storage).to_s.delete_suffix('.md5') }
    end

    def md5_sidecar_paths
      Pathname.glob(File.join(zip_storage, s3_key('.*.md5')))
    end
  end
end
