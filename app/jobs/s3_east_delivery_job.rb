# Same as parent class, just a different queue.
class S3EastDeliveryJob < S3WestDeliveryJob
  queue_as :s3_us_east_1_delivery # note: still needs proper ENVs for AWS_REGION, etc.

  # @param [String] druid
  # @param [Integer] version
  # @param [String] part_s3_key
  # @param [Hash<Symbol => String, Integer>] metadata Zip info
  # @see PlexerJob#perform warning about why metadata must be passed
  def perform(druid, version, part_s3_key, metadata)
    ENV['AWS_PROFILE'] = 'us_east_1'
    ENV['AWS_BUCKET_NAME'] = Settings.archive_endpoints.aws_s3_east_1.storage_location
    s3_part = bucket.object(part_s3_key) # Aws::S3::Object
    return if s3_part.exists?
    s3_part.put(
      body: dvz_part.file,
      content_md5: zip.hex_to_base64(metadata[:checksum_md5]),
      metadata: stringify_values(metadata)
    )
    ResultsRecorderJob.perform_later(druid, version, part_s3_key, self.class.to_s)
  end
end
