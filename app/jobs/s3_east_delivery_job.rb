# frozen_string_literal: true

# @see PreservationCatalog::Aws for how S3 credentials and bucket are configured
# @note This name is slightly misleading, as this class solely deals with AWS US East 1 endpoint
class S3EastDeliveryJob < AbstractDeliveryJob
  queue_as :s3_us_east_1_delivery

  def bucket
    S3::AwsProvider.new(
      region: Settings.zip_endpoints.aws_s3_east_1.region,
      access_key_id: Settings.zip_endpoints.aws_s3_east_1.access_key_id,
      secret_access_key: Settings.zip_endpoints.aws_s3_east_1.secret_access_key
    ).bucket
  end
end
