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
    S3EndpointDeliveryJob => 1
  }

  validates :endpoint_name, presence: true, uniqueness: true
  validates :endpoint_type, presence: true
  validates :endpoint_node, presence: true
  validates :storage_location, presence: true
  validates :recovery_cost, presence: true

  # iterates over the storage roots enumerated in settings, creating an endpoint for each if one doesn't
  # already exist.
  # returns an array with the result of the ActiveRecord find_or_create_by! call for each settings entry (i.e.,
  # storage root Endpoint rows defined in the config, whether newly created by this call, or previously created).
  # NOTE: this adds new entries from the config, and leaves existing entries alone, but won't delete anything.
  # TODO: figure out deletion based on config?
  def self.seed_storage_root_endpoints_from_config(endpoint_type, preservation_policies)
    HostSettings.storage_roots.map do |storage_root_name, storage_root_location|
      find_or_create_by!(endpoint_name: storage_root_name.to_s) do |endpoint|
        endpoint.endpoint_type = endpoint_type
        endpoint.endpoint_node = Settings.endpoints.storage_root_defaults.endpoint_node
        endpoint.storage_location = File.join(storage_root_location, Settings.moab.storage_trunk)
        endpoint.recovery_cost = Settings.endpoints.storage_root_defaults.recovery_cost
        endpoint.preservation_policies = preservation_policies
      end
    end
  end

  def self.seed_archive_endpoints_from_config(preservation_policies)
    Settings.archive_endpoints.map do |endpoint_name, endpoint_config|
      find_or_create_by!(endpoint_name: endpoint_name.to_s) do |endpoint|
        endpoint.endpoint_type = EndpointType.find_by!(type_name: endpoint_config.endpoint_type_name)
        endpoint.endpoint_node = endpoint_config.endpoint_node
        endpoint.storage_location = endpoint_config.storage_location
        endpoint.access_key = endpoint_config.access_key
        endpoint.recovery_cost = endpoint_config.recovery_cost
        endpoint.preservation_policies = preservation_policies
      end
    end
  end

  # TODO: move to EndpointType class?  e.g. .default_for_storage_root
  def self.default_storage_root_endpoint_type
    EndpointType.find_by!(type_name: Settings.endpoints.storage_root_defaults.endpoint_type_name)
  end

  def to_h
    {
      endpoint_name: endpoint_name,
      endpoint_type_name: endpoint_type.type_name,
      endpoint_type_class: endpoint_type.endpoint_class,
      endpoint_node: endpoint_node,
      storage_location: storage_location,
      recovery_cost: recovery_cost
    }
  end

  def to_s
    "<Endpoint: #{to_h}>"
  end
end
