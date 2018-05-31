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
    targets(druid, version).each do |worker|
      worker.perform_later(druid, version)
    end
  end

  # @return [Array<Class>] EndpointDeliveryBase-descending classes to be targeted
  def targets(druid, version)
    Endpoint
      .joins(:endpoint_type, preserved_copies: [:preserved_object])
      .where(
        endpoint_types: { endpoint_class: 'archive' },
        preserved_objects: { druid: druid },
        preserved_copies: { version: version }
      )
      .map do |ep|
        Rails.logger.error("Archive Endpoint (id: #{ep.id}) has no delivery_class") unless ep.delivery_class
        ep.delivery_class
      end.compact
  end
end
