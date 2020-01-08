# frozen_string_literal: true

# Same as parent class, just a different queue.
class S3EastDeliveryJob < S3WestDeliveryJob
  queue_as :s3_us_east_1_delivery # note: still needs proper ENVs for AWS_REGION, etc.

  def bucket
    PreservationCatalog::S3.configure(
      region: Settings.zip_endpoints.aws_s3_east_1.region,
      access_key_id: Settings.zip_endpoints.aws_s3_east_1.access_key_id,
      secret_access_key: Settings.zip_endpoints.aws_s3_east_1.secret_access_key
    )
    PreservationCatalog::S3.bucket
  end
end
