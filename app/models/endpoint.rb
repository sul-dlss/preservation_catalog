##
# Metadata about a replication endpoint, including a unique human
# readable name, and the type of endpoint it is (e.g. :online, :archive).
class Endpoint < ApplicationRecord
  has_many :preservation_copies, dependent: :restrict_with_exception
  belongs_to :endpoint_type
  has_and_belongs_to_many :preservation_policies

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
    Settings.moab.storage_roots.map do |storage_root_name, storage_root_location|
      find_or_create_by!(endpoint_name: storage_root_name.to_s) do |endpoint|
        endpoint.endpoint_type = endpoint_type
        endpoint.endpoint_node = Settings.endpoints.storage_root_defaults.endpoint_node
        endpoint.storage_location = File.join(storage_root_location, Settings.moab.storage_trunk)
        endpoint.recovery_cost = Settings.endpoints.storage_root_defaults.recovery_cost
        endpoint.preservation_policies = preservation_policies
      end
    end
  end

  def self.default_storage_root_endpoint_type
    EndpointType.find_by!(type_name: Settings.endpoints.storage_root_defaults.endpoint_type_name)
  end
end
