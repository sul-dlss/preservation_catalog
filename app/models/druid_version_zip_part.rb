# Just a regular model, not an ActiveRecord-backed model
class DruidVersionZipPart
  attr_reader :dvz, :part_filename
  delegate :base64digest, :hexdigest, to: :md5
  delegate :druid, :part_paths, :hex_to_base64, :zip_command, :zip_version, to: :dvz

  alias s3_key part_filename

  # @param [DruidVersionZip] dvz
  # @param [String] part_filename, e.g. 'ab/123/cd/4567/ab123cd4567.v0001.z03'
  # @note part_filename locates the file inside zip_storage AND is the s3_key
  # @see [S3 key name performance implications] https://docs.aws.amazon.com/AmazonS3/latest/dev/request-rate-perf-considerations.html
  def initialize(dvz, part_filename)
    @dvz = dvz
    @part_filename = part_filename
  end

  # @return [String] the filename extension, e.g. '.z03'
  def extname
    File.extname(part_filename)
  end

  # @return [File] opened zip file
  def file
    File.open(file_path)
  end

  # @return [String] Path to the local temporary transfer zip (part)
  def file_path
    File.join(Settings.zip_storage, part_filename)
  end

  # @return [Digest::MD5] cached md5 object
  def md5
    @md5 ||= Digest::MD5.file(file_path)
  end

  # @return [Hash<Symbol => [String, Integer]>] metadata to accompany Zip (part) file to an endpoint
  def metadata
    {
      checksum_md5: hexdigest,
      size: size,
      parts_count: part_paths.count,
      zip_cmd: zip_command,
      zip_version: zip_version
    }
  end

  # @return [Integer] Zip file size
  def size
    @size ||= FileTest.size(file_path)
  end
end
