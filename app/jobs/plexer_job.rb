# Responsibilities:
# Record zip metadata info in DB.
# Split message out to all necessary endpoints.
# For example:
#   Endpoint1Delivery.perform_later(druid, version)
#   Endpoint2Delivery.perform_later(druid, version)
#   ...
class PlexerJob < ApplicationJob
  queue_as :zips_made

  before_enqueue { |job| job.zip_info_check!(job.arguments.third) }

  # @param [String] druid
  # @param [Integer] version
  # @param [Hash<Symbol => String>] metadata Zip info
  # @option metadata [Integer] :size
  # @option metadata [String] :zip_cmd
  # @option metadata [String] :checksum_md5
  def perform(druid, version, metadata)
    targets(druid, version).each do |worker|
      worker.perform_later(druid, version, metadata)
    end
  end

  # @return [Array<Class>] Endpoint delivery classes to be targeted
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
