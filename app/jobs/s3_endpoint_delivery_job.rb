# Posts zips to S3, if needed.
# Notify ResultsRecorderJob, if posted.
# @see PreservationCatalog::S3 for how S3 credentials and bucket are configured
class S3EndpointDeliveryJob < DruidVersionJobBase
  queue_as :s3_endpoint_delivery
  delegate :bucket, to: PreservationCatalog::S3
  # note: DruidVersionJobBase gives us `zip`

  before_enqueue { |job| job.zip_info_check!(job.arguments.third) }

  # @param [String] druid
  # @param [Integer] version
  # @param [Hash<Symbol => String>] metadata Zip info
  # @todo once zip construction is formalized, insert reproducible call in zip_cmd
  def perform(druid, version, metadata)
    return if s3_object.exists?
    s3_object.put(body: zip.file, content_md5: metadata[:checksum_md5], metadata: metadata)
    ResultsRecorderJob.perform_later(druid, version, self.class.to_s)
  end

  # @return [Aws::S3::Object]
  def s3_object
    @s3_object ||= bucket.object(zip.s3_key)
  end
end
