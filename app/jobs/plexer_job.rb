# Responsibilities:
# Interpret replication logic.
# Split message out to all necessary endpoints.
# For example:
#   Endpoint1Delivery.perform_later(druid, version)
#   Endpoint2Delivery.perform_later(druid, version)
#   ...
class PlexerJob < ApplicationJob
  queue_as :zips_made

  # @param [String] druid
  # @param [Integer] version
  def perform(druid, version)
    S3EndpointDeliveryJob.perform_later(druid, version)
  end
end
