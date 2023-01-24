# frozen_string_literal: true

module Replication
  # @see Replication::AwsProvider for how S3 credentials and bucket are configured
  # @note this class name appears in config files for the endpoints for which it delivers content.
  #   Please update the configs for the various environments if it's renamed or moved.
  # @note This name is slightly misleading, as this class solely deals with AWS US East 1 endpoint
  class S3EastDeliveryJob < Replication::DeliveryJobBase
    queue_as :replication_aws_us_east_1_delivery

    # perform method is defined in DeliveryJobBase

    def bucket
      Replication::AwsProvider.new(
        region: Settings.zip_endpoints.aws_s3_east_1.region,
        access_key_id: Settings.zip_endpoints.aws_s3_east_1.access_key_id,
        secret_access_key: Settings.zip_endpoints.aws_s3_east_1.secret_access_key
      ).bucket
    end
  end
end
