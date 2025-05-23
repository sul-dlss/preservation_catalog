# frozen_string_literal: true

module Replication
  # @see Replication::GcpProvider for how S3 credentials and bucket are configured
  # @note this class name appears in config files for the endpoints for which it delivers content.
  #   Please update the configs for the various environments if it's renamed or moved.
  class GcpDeliveryJob < Replication::DeliveryJobBase
    queue_as :gcp_us_south_delivery

    # perform method is defined in DeliveryJobBase

    def bucket
      Replication::GcpProvider.new(
        region: Settings.zip_endpoints.gcp_s3_south_1.region,
        access_key_id: Settings.zip_endpoints.gcp_s3_south_1.access_key_id,
        secret_access_key: Settings.zip_endpoints.gcp_s3_south_1.secret_access_key
      ).bucket
    end
  end
end
