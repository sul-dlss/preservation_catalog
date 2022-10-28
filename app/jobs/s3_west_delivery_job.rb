# frozen_string_literal: true

# @see S3::Aws for how S3 credentials and bucket are configured
# @note this class name appears in the configuration for the endpoints for which it delivers content.
#   Please update the configs for the various environments if it's renamed or moved.
# @note This name is slightly misleading, as this class solely deals with AWS US West 2 endpoint
class S3WestDeliveryJob < AbstractDeliveryJob
  queue_as :s3_us_west_2_delivery

  def bucket
    S3::AwsProvider.new(
      region: Settings.zip_endpoints.aws_s3_west_2.region,
      access_key_id: Settings.zip_endpoints.aws_s3_west_2.access_key_id,
      secret_access_key: Settings.zip_endpoints.aws_s3_west_2.secret_access_key
    ).bucket
  end
end
