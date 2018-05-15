# Posts zips to S3
# @see PreservationCatalog::S3 for how S3 credentials and bucket are configured
# Upload zip if needed.
# Notify ResultsRecorderJob.
class S3EndpointDeliveryJob < EndpointDeliveryBase
  queue_as :s3_endpoint_delivery
  delegate :bucket, to: PreservationCatalog::S3
  # note: EndpointDeliveryBase gives us `zip`

  # @param [String] druid
  # @param [Integer] version
  # @todo once zip construction is formalized, insert reproducible call in zip_cmd
  def perform(druid, version)
    return if s3_object.exists?
    s3_object.put(body: zip.file, content_md5: zip.md5, metadata: { zip_cmd: 'zip -X ...', checksum_md5: zip.md5 })
    ResultsRecorderJob.perform_later(druid, version, 's3', '12345ABC') # value will be from zip.checksum
  end

  # @return [Aws::S3::Object]
  def s3_object
    @s3_object ||= bucket.object(zip.s3_key)
  end
end
