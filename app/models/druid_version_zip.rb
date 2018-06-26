require 'open3'

# Just a regular model, not an ActiveRecord-backed model
class DruidVersionZip
  attr_reader :druid, :version
  delegate :base64digest, :hexdigest, to: :md5

  # @param [String] druid
  # @param [Integer] version
  def initialize(druid, version)
    @druid = DruidTools::Druid.new(druid.downcase)
    @version = version
  end

  # Creates a zip of Druid-Version content.
  # Changes directory so that the storage root (and druid tree) are not part of
  # the archival directory structure, just the object, e.g. starting at 'ab123cd4567/...' directory,
  # not 'ab/123/cd/4567/ab123cd4567/...'
  def create_zip!
    ensure_zip_directory!
    Dir.chdir(work_dir.to_s) do
      combined, status = Open3.capture2e(zip_command)
      raise "zipmaker failure #{combined}" unless status.success?
    end
  end

  # Ensure the directory the zip will live in exists
  # @return [Pathname] the existing or created directory
  def ensure_zip_directory!
    Pathname.new(file_path).tap { |pn| pn.dirname.mkpath }
  end

  # @return [String]
  # @see [S3 key name performance implications] https://docs.aws.amazon.com/AmazonS3/latest/dev/request-rate-perf-considerations.html
  # @example return 'ab/123/cd/4567/ab123cd4567/ab123cd4567.v0001.zip'
  def s3_key
    druid.tree.join('/') + ".#{v_version}.zip"
  end

  # @return [File] opened zip file
  def file
    File.open(file_path)
  end

  # @return [String] Path to the local temporary transfer zip
  def file_path
    File.join(Settings.zip_storage, s3_key)
  end

  # WITHOUT (re)digesting the file, convert a hexdigest MD5 value to base64-endcoded equivalent.
  # Motivation: we store hexdigest and S3 requires base64 in headers.
  # @param [String] hex
  # @return [String] base64 equivalent
  def hex_to_base64(hex)
    [[hex].pack("H*")].pack("m0")
  end

  # @return [Digest::MD5] cached md5 object
  def md5
    @md5 ||= Digest::MD5.file(file_path)
  end

  # @return [Hash<Symbol => [String, Integer]>] metadata to accompany Zip file to an endpoint
  def metadata
    { checksum_md5: hexdigest, size: size, zip_cmd: zip_command, zip_version: zip_version }
  end

  def moab_version_path
    @moab_version_path ||= Moab::StorageServices.object_version_path(druid.id, version)
  end

  # @return [Integer] Zip file size
  def size
    @size ||= FileTest.size(file_path)
  end

  # @return [String] "v" with zero-padded 4-digit version, e.g., v0001
  def v_version
    format("v%04d", version)
  end

  # @return [Pathname] The proper directory in which to execute zip_command
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
    "zip -vr0X -sv -s #{zip_split_size} #{file_path} #{druid.id}/#{v_version}"
  end

  # We presume the system guts do not change underneath a given class instance.
  # We want to avoid shelling out (forking) unnecessarily, just for the version.
  def zip_version
    @@zip_version ||= fetch_zip_version # rubocop:disable Style/ClassVars
  end

  private

  # @return [String] e.g. 'Zip 3.0 (July 5th 2008)' or 'Zip 3.0.1'
  def fetch_zip_version
    match = nil
    IO.popen("zip -v") do |io|
      re = zip_version_regexp
      io.find { |line| match = line.match(re) }
    end
    return match[1] if match && match[1].present?
    raise 'No version info matched from `zip -v` ouptut'
  end

  # @return [String] the option included with "zip -s"
  def zip_split_size
    '10g'
  end

  def zip_version_regexp
    /This is (Zip \d+(\.\d)+\s*(\(.*\d{4}\))?)/
  end
end
