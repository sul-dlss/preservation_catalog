##
# Metadata about a replication endpoint, including a unique human
# readable name, and the type of endpoint it is (e.g. :online, :archive).
class Endpoint < ApplicationRecord
  has_many :preserved_copies, dependent: :restrict_with_exception
  belongs_to :endpoint_type
  has_and_belongs_to_many :preservation_policies

  validates :endpoint_name, presence: true, uniqueness: true
  validates :endpoint_type, presence: true
  validates :endpoint_node, presence: true
  validates :storage_location, presence: true
  validates :recovery_cost, presence: true

  # for the given druid, what endpoints should have preserved copies?
  # note: must be combined with other scopes and filters to determine, e.g.,
  # which archive endpoints are lacking a preserved copy for a given version.
  scope :target_endpoints, lambda { |druid|
    joins(preservation_policies: [:preserved_objects]).where(preserved_objects: { druid: druid })
  }

  scope :in_need_of_archive_copy, lambda { |druid, version|
    # cast version to int for nicer errors in the case of bad input.  though ActiveRecord/ARel would still protect
    # against injection attacks even without using a bind var (e.g. a string passed in for an int col query would
    # silently be inserted as 0, an INTEGER).
    pc_table = PreservedCopy.arel_table
    ep_table = Endpoint.arel_table
    endpoint_has_pres_copy_subquery =
      PreservedCopy.where(
        pc_table[:endpoint_id].eq(ep_table[:id])
          .and(pc_table[:version].eq(version.to_i))
      ).exists

    target_endpoints(druid).archive.where.not(endpoint_has_pres_copy_subquery)
  }

  scope :archive, lambda {
    # TODO: maybe endpoint_class should be an enum or a constant?
    joins(:endpoint_type).where(endpoint_types: { endpoint_class: 'archive' })
  }

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

  def self.seed_archive_endpoints_from_config(endpoint_type, preservation_policies)
    HostSettings.archive_endpoints.map do |endpoint_name, endpoint_config|
      find_or_create_by!(endpoint_name: endpoint_name.to_s) do |endpoint|
        endpoint.endpoint_type = endpoint_type
        endpoint.endpoint_node = endpoint_config.endpoint_node
        endpoint.storage_location = endpoint_config.storage_location
        endpoint.access_key = endpoint_config.access_key
        endpoint.recovery_cost = Settings.endpoints.archive_defaults.recovery_cost
        endpoint.preservation_policies = preservation_policies
      end
    end
  end

  # TODO: move to EndpointType class?  e.g. .default_for_storage_root
  def self.default_storage_root_endpoint_type
    EndpointType.find_by!(type_name: Settings.endpoints.storage_root_defaults.endpoint_type_name)
  end

  # TODO: move to EndpointType class?  e.g. .default_for_archive
  def self.default_archive_endpoint_type
    EndpointType.find_by!(type_name: Settings.endpoints.archive_defaults.endpoint_type_name)
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
