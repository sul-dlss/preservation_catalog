# Different provider than parent class
class IbmSouthDeliveryJob < S3WestDeliveryJob
  queue_as :ibm_us_south_delivery # note: as with Amazon, still needs proper ENVs for AWS_REGION, etc.
  delegate :bucket, to: PreservationCatalog::Ibm
end
