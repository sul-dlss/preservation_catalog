# Just a regular model, not an ActiveRecord-backed model
class DruidVersionZip
  attr_reader :druid, :version

  # @param [String] druid
  # @param [Integer] version
  def initialize(druid, version)
    @druid = DruidTools::Druid.new(druid.downcase)
    @version = version
  end

  # @return [String]
  # @see [S3 key name performance implications] https://docs.aws.amazon.com/AmazonS3/latest/dev/request-rate-perf-considerations.html
  # @example return 'ab/123/cd/4567/ab123cd4567/ab123cd4567.v0001.zip'
  def s3_key
    druid.tree.join('/') + format(".v%04d.zip", version)
  end

  # @return [File] opened zip file
  def file
    File.open(file_path)
  end

  # @return [String] Path to the local temporary transfer zip
  def file_path
    File.join(Settings.zip_storage, s3_key)
  end

  def moab_version_path
    @moab_version_path ||= Moab::StorageServices.object_version_path(druid.id, version)
  end

  # Currently computed live, soon will fetch from checksum storage
  # @return [String] md5 base64-encoded checksum
  # @todo Fetch (and cache) md5 from checksum storage
  def md5
    @md5 ||= Digest::MD5.file(file_path).base64digest
  end

  # @return [String] shell command to create this zip
  def zip_command
    "zip -vr0X -s 10g #{file_path} #{moab_version_path}"
  end

  # @return [String] shell command to unzip
  # def unzip_command
  #   "unzip #{file_path} -d #{place_to_unzip}"
  # end

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

  def zip_version_regexp
    /This is (Zip \d+(\.\d)+\s*(\(.*\d{4}\))?)/
  end
end
