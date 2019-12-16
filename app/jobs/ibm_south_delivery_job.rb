# frozen_string_literal: true

# Different provider than parent class
class IbmSouthDeliveryJob < S3WestDeliveryJob
  queue_as :ibm_us_south_delivery # note: as with Amazon, still needs proper ENVs for AWS_REGION, etc.

  def bucket
    PreservationCatalog::Ibm.configure(
      region: Settings.zip_endpoints.ibm_us_south.region,
      access_key_id: Settings.zip_endpoints.ibm_us_south.access_key_id,
      secret_access_key: Settings.zip_endpoints.ibm_us_south.secret_access_key
    )
    PreservationCatalog::S3.bucket
  end
end
