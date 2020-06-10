# frozen_string_literal: true

# Different provider than parent class
# @note The IBM delivery job inherits from an AWS job because the mechanics only differ in bucket name lookup
class IbmSouthDeliveryJob < S3WestDeliveryJob
  queue_as :ibm_us_south_delivery

  def bucket
    PreservationCatalog::IbmProvider.new(
      region: Settings.zip_endpoints.ibm_us_south.region,
      access_key_id: Settings.zip_endpoints.ibm_us_south.access_key_id,
      secret_access_key: Settings.zip_endpoints.ibm_us_south.secret_access_key
    ).bucket
  end
end
