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

  # Currently computed live, soon will fetch from checksum storage
  # @return [String] md5 checksum
  # @todo Fetch (and cache) md5 from checksum storage
  def md5
    Digest::MD5.file(file_path).hexdigest
  end
end
