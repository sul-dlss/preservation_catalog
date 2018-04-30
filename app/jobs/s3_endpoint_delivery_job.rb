# require aws/s3 lib
#
# Responsibilities:
# "Speak S3"
# Check if corresponding zip exists in S3.
# Upload zip if needed.
# Notify ResultsRecorderJob.
class S3EndpointDeliveryJob < EndpointDeliveryBase
  queue_as :s3_enpoint_delivery
  # note: EndpointDeliveryBase gives us `zip`

  # @param [String] druid
  # @param [Integer] version
  def perform(druid, version)
    ResultsRecorderJob.perform_later(druid, version, 's3', '12345ABC') # value will be from zip.checksum
  end
end
