# frozen_string_literal: true

module Replication
  # Given a druid, a version, and an optional file extension and storage location, return all zip part paths (or S3 keys)
  class ZipPartPathfinder
    DEFAULT_EXTENSION = '.zip'
    CHECKSUM_EXTENSION = '.md5'

    attr_reader :druid

    # @param [String] druid the repository ID
    # @param [Integer] version the version number
    # @param [String] storage_location The path of storage_root/storage_trunk with the druid tree.
    # @param [String] extension The file extension that will be used in the S3 key (default: DEFAULT_EXTENSION)
    def initialize(druid:, version:, storage_location: nil, extension: nil)
      @druid = DruidTools::Druid.new(druid.downcase, storage_location)
      @extension = extension || DEFAULT_EXTENSION
      @storage_location = storage_location
      @version = version
    end

    # NOTE: if there is only ONE part, it will end .zip;  if there are multiple parts,
    #  the last one will end .zip, so two parts is:  .z01, zip. (this agrees with zip utility)
    # @return [Array<Pathname>] Existing pathnames for zip parts based on
    #   glob (.zip, .z01, .z02, etc.).
    def zip_paths
      Pathname.glob(file_path.sub(/#{DEFAULT_EXTENSION}\z/, '.z*'))
              .reject { |path| path.extname.downcase == CHECKSUM_EXTENSION }
    end

    # @see #zip_paths
    # @return [Array<String>] Existing relative path strings for zip parts based on
    #   glob (.zip, .z01, .z02, etc.) corresponding to S3 part keys
    def zip_keys
      zip_paths.map { |path| path.relative_path_from(zip_storage_path).to_s }
    end

    def zip_keys_match_sidecars?
      zip_keys.to_set == zip_keys_from_md5_sidecars.to_set
    end

    # @return [Array<Pathname>] all extant zip part and checksum files for this dvz (e.g. bc123df4567.zip, bc123df4567.z01, bc123df4567.zip.md5,
    #  bc123df4567.z01.md5, etc)
    def all_file_paths
      @all_file_paths = Pathname.glob(File.join(zip_storage_path, s3_key(suffix: '.*')))
    end

    # @raise [StandardError] if storage_location is not available (should have been provided in constructor)
    def moab_version_root
      raise "cannot determine Moab version root for #{druid.id} v#{version}, storage_location not provided" unless storage_location

      @moab_version_root ||= "#{druid.path}/#{version_string}"
    end

    # @return [String] Path to the local temporary transfer root (.zip) part
    def file_path
      File.join(zip_storage_path, s3_key).to_s
    end

    # @return [String] "v" with zero-padded 4-digit version, e.g., v0001
    def version_string
      format('v%04d', version)
    end

    # @return [String] s3_key for the zip part specified by the druid, version, and extension
    # @see [S3 key name performance implications] https://docs.aws.amazon.com/AmazonS3/latest/dev/request-rate-perf-considerations.html
    # @example return 'ab/123/cd/4567/ab123cd4567.v0001.zip'
    def s3_key(suffix: ".#{extension}")
      "#{druid.tree.join('/')}.#{version_string}#{suffix}"
    end

    private

    attr_reader :extension, :storage_location, :version

    # @return [Array<String>] relative paths, i.e. s3_part_keys for existing parts based on the md5 sidecar files
    def zip_keys_from_md5_sidecars
      md5_sidecar_paths.map do |md5_path|
        md5_path.relative_path_from(zip_storage_path).to_s.delete_suffix(CHECKSUM_EXTENSION)
      end
    end

    def md5_sidecar_paths
      Pathname.glob(File.join(zip_storage_path, s3_key(suffix: ".*#{CHECKSUM_EXTENSION}")))
    end

    # @return [Pathname] path to the zip storage root
    def zip_storage_path
      @zip_storage_path ||= Pathname.new(Settings.zip_storage)
    end
  end
end
