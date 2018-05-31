##
# metadata about a specific replication endpoint
class EndpointType < ApplicationRecord
  # TODO: this should eventually become a regular int Enum.  String Enums work and are tested in Rails 5,
  # but are neither documented nor officially supported, and may be de-supported in the future.
  # see https://bibwild.wordpress.com/2016/09/06/rails5-and-earlier-activerecordenum-supports-strings-in-db/
  enum endpoint_class: {
    'online' => 'online',
    'archive' => 'archive'
  }

  has_many :endpoints, dependent: :restrict_with_exception

  validates :type_name, presence: true, uniqueness: true
  # TODO: maybe endpoint_class should be an enum or a constant?
  validates :endpoint_class, inclusion: { in: endpoint_classes.keys }

  # iterates over the endpoint types enumerated in the settings, creating any that don't already exist.
  # @return [Array<EndpointType>] the EndpointType list for the endpoint types defined in the config (all entries,
  #   including any entries that may have been seeded already)
  # @note this adds new entries from the config, and leaves existing entries alone, but won't delete anything.
  # TODO: figure out deletion/update based on config?
  def self.seed_from_config
    Settings.endpoint_types.map do |endpoint_type_name, endpoint_type_config|
      # we want to find only by the name, but we want to define the endpoint_class too if we actually add a row
      find_or_create_by!(type_name: endpoint_type_name.to_s) do |endpoint_type|
        endpoint_type.endpoint_class = endpoint_type_config.endpoint_class
      end
    end
  end

  def self.default_for_storage_roots
    EndpointType.find_by!(type_name: Settings.endpoints.storage_root_defaults.endpoint_type_name)
  end
end
