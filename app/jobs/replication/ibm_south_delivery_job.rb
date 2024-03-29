# frozen_string_literal: true

module Replication
  # @see Replication::IbmProvider for how S3 credentials and bucket are configured
  # @note this class name appears in config files for the endpoints for which it delivers content.
  #   Please update the configs for the various environments if it's renamed or moved.
  class IbmSouthDeliveryJob < Replication::DeliveryJobBase
    queue_as :ibm_us_south_delivery

    # perform method is defined in DeliveryJobBase

    def bucket
      Replication::IbmProvider.new(
        region: Settings.zip_endpoints.ibm_us_south.region,
        access_key_id: Settings.zip_endpoints.ibm_us_south.access_key_id,
        secret_access_key: Settings.zip_endpoints.ibm_us_south.secret_access_key
      ).bucket
    end
  end
end
