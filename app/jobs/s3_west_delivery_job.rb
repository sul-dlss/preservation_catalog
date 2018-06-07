# Posts zips to S3, if needed.
# Notify ResultsRecorderJob, if posted.
# @see PreservationCatalog::S3 for how S3 credentials and bucket are configured
class S3WestDeliveryJob < DruidVersionJobBase
  queue_as :s3_us_west_1_delivery
  delegate :bucket, to: PreservationCatalog::S3
  # note: DruidVersionJobBase gives us `zip`

  before_enqueue { |job| job.zip_info_check!(job.arguments.third) }

  # @param [String] druid
  # @param [Integer] version
  # @param [Hash<Symbol => String, Integer>] metadata Zip info
  # @see PlexerJob#perform warning about why metadata must be passed
  def perform(druid, version, metadata)
    return if s3_object.exists?
    s3_object.put(
      body: zip.file,
      content_md5: zip.hex_to_base64(metadata[:checksum_md5]),
      metadata: stringify_values(metadata)
    )
    ResultsRecorderJob.perform_later(druid, version, self.class.to_s)
  end

  # coerce size int to string (all values must be strings)
  # @param [Hash<Symbol => #to_s>] metadata
  # @return [Hash<Symbol => String>] metadata
  def stringify_values(metadata)
    metadata.merge(size: metadata[:size].to_s)
  end

  # @return [Aws::S3::Object]
  def s3_object
    @s3_object ||= bucket.object(zip.s3_key)
  end
end
