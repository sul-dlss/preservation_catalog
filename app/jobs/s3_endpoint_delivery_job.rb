# Posts zips to S3
# @see PreservationCatalog::S3 for how S3 credentials and bucket are configured
# Upload zip if needed.
# Notify ResultsRecorderJob.
class S3EndpointDeliveryJob < EndpointDeliveryBase
  queue_as :s3_enpoint_delivery
  delegate :bucket, to: PreservationCatalog::S3
  # note: EndpointDeliveryBase gives us `zip`

  # @param [String] druid
  # @param [Integer] version
  def perform(druid, version)
    return if object.exists?
    object.put(zip.file)
    ResultsRecorderJob.perform_later(druid, version, 's3', '12345ABC') # value will be from zip.checksum
  end

  def object
    @object ||= bucket.object(zip.s3_key)
  end
end
