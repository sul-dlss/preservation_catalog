##
# Metadata about a replication endpoint, including a unique human
# readable name, and the type of endpoint it is (e.g. :online, :archive).
class Endpoint < ApplicationRecord
  has_many :preserved_copies, dependent: :restrict_with_exception
  belongs_to :endpoint_type
  has_and_belongs_to_many :preservation_policies

  # @note Hash values cannot be modified without migrating any associated persisted data.
  # @see [enum docs] http://api.rubyonrails.org/classes/ActiveRecord/Enum.html
  enum delivery_class: {
    S3WestDeliveryJob => 1,
    S3EastDeliveryJob => 2
  }

  validates :endpoint_name, presence: true, uniqueness: true
  validates :endpoint_type, presence: true
  validates :endpoint_node, presence: true
  validates :storage_location, presence: true

  scope :archive, lambda {
    joins(:endpoint_type).where(endpoint_types: { endpoint_class: 'archive' })
  }

  # for the given druid, which archive endpoints should have preserved copies?
  scope :archive_targets, lambda { |druid|
    archive.joins(preservation_policies: [:preserved_objects]).where(preserved_objects: { druid: druid })
  }

  # Use a queue to validate PreservedCopy objects
  def validate_expired_checksums!
    raise 'Endpoint is not "online" type' unless endpoint_type.online?
    pcs = preserved_copies.fixity_check_expired
    Rails.logger.info "Endpoint #{id} (#{endpoint_name}), # of preserved_copies to be checksum validated: #{pcs.count}"
    pcs.find_each { |pc| ChecksumValidationJob.perform_later(pc) }
  end

  # @param [String] druid
  # @return [Hash<Integer => Array<Integer>>] Archive Endpoint IDs mapped to found version numbers for one druid
  # @example Endpoint.ids_to_versions_found('zz964cr9336')
  #  { 11 => [1, 2, 3], 12 => [1, 2, 3], 13 => [] }
  def self.ids_to_versions_found(druid)
    archive_targets(druid)
      .left_outer_joins(:preserved_copies)
      .where("preserved_copies.preserved_object_id = preserved_objects.id OR preserved_copies.id IS NULL")
      .distinct
      .pluck(:id, :version)
      .each_with_object({}) do |(id, version), h|
        h[id] ||= []
        h[id] << version if version
      end
  end

  # Iterates over the storage roots enumerated in settings, creating an Endpoint for each if it doesn't already exist.
  # @param endpoint_type [EndpointType] the EndpointType to use for any newly created Endpoint records
  # @param preservation_policies [Enumerable<PreservationPolicy>] the list of preservation policies
  #   which any newly created endpoints implement.
  # @return [Array<Endpoint>] the Endpoint list for the local storage roots defined in the config (all entries,
  #   including any entries that may have been seeded already)
  # @note this adds new entries from the config, and leaves existing entries alone, but won't delete anything.
  # TODO: figure out deletion/update based on config?
  def self.seed_storage_root_endpoints_from_config(endpoint_type, preservation_policies)
    HostSettings.storage_roots.map do |storage_root_name, storage_root_location|
      find_or_create_by!(endpoint_name: storage_root_name.to_s) do |endpoint|
        endpoint.endpoint_type = endpoint_type
        endpoint.endpoint_node = Settings.endpoints.storage_root_defaults.endpoint_node
        endpoint.storage_location = File.join(storage_root_location, Settings.moab.storage_trunk)
        endpoint.preservation_policies = preservation_policies
      end
    end
  end

  # iterates over the archive endpoints enumerated in settings, creating an Endpoint for each if one doesn't
  # already exist.
  # @param preservation_policies [Enumerable<PreservationPolicy>] the list of preservation policies
  #   which the newly created endpoints implement.
  # @return [Array<Endpoint>] the Endpoint list for the archive endpoints defined in the config (all entries,
  #   including any entries that may have been seeded already)
  # @note this adds new entries from the config, and leaves existing entries alone, but won't delete anything.
  # TODO: figure out deletion/update based on config?
  def self.seed_archive_endpoints_from_config(preservation_policies)
    return unless Settings.archive_endpoints
    Settings.archive_endpoints.map do |endpoint_name, endpoint_config|
      find_or_create_by!(endpoint_name: endpoint_name.to_s) do |endpoint|
        endpoint.endpoint_type = EndpointType.find_by!(type_name: endpoint_config.endpoint_type_name)
        endpoint.endpoint_node = endpoint_config.endpoint_node
        endpoint.storage_location = endpoint_config.storage_location
        endpoint.preservation_policies = preservation_policies
        endpoint.delivery_class = Endpoint.delivery_classes[endpoint_config.delivery_class.constantize]
      end
    end
  end

  def to_h
    {
      endpoint_name: endpoint_name,
      endpoint_type_name: endpoint_type.type_name,
      endpoint_type_class: endpoint_type.endpoint_class,
      endpoint_node: endpoint_node,
      storage_location: storage_location
    }
  end

  def to_s
    "<Endpoint: #{to_h}>"
  end
end
