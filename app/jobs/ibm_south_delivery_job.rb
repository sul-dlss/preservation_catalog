# frozen_string_literal: true

# @see PreservationCatalog::Aws for how S3 credentials and bucket are configured
class IbmSouthDeliveryJob < AbstractDeliveryJob
  queue_as :ibm_us_south_delivery

  def bucket
    S3::IbmProvider.new(
      region: Settings.zip_endpoints.ibm_us_south.region,
      access_key_id: Settings.zip_endpoints.ibm_us_south.access_key_id,
      secret_access_key: Settings.zip_endpoints.ibm_us_south.secret_access_key
    ).bucket
  end
end
