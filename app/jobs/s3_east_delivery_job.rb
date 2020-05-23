# frozen_string_literal: true

# Same as parent class, just a different queue.
# @note This name is slightly misleading, as this class solely deals with AWS US East 1 endpoint
class S3EastDeliveryJob < S3WestDeliveryJob
  queue_as :s3_us_east_1_delivery

  def bucket
    PreservationCatalog::Aws.configure(
      region: Settings.zip_endpoints.aws_s3_east_1.region,
      access_key_id: Settings.zip_endpoints.aws_s3_east_1.access_key_id,
      secret_access_key: Settings.zip_endpoints.aws_s3_east_1.secret_access_key
    )
    PreservationCatalog::Aws.bucket
  end
end
