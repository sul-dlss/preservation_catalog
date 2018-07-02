# Metadata about an endpoint which stores zipped archives of version directories from Moab
# objects.
class ArchiveEndpoint < ApplicationRecord
  has_many :archive_preserved_copies, dependent: :restrict_with_exception
  has_and_belongs_to_many :preservation_policies

  # @note Hash values cannot be modified without migrating any associated persisted data.
  # @see [enum docs] http://api.rubyonrails.org/classes/ActiveRecord/Enum.html
  # TODO: switch this to use plain strings representing the class name
  enum delivery_class: {
    S3WestDeliveryJob => 1,
    S3EastDeliveryJob => 2
  }

  validates :endpoint_name, presence: true, uniqueness: true
  # TODO: after switching to string, validate that input resolves to class which #is_a class of the right type?
  validates :delivery_class, presence: true

  # iterates over the archive endpoints enumerated in settings, creating an ArchiveEndpoint for each if one doesn't
  # already exist.
  # @param preservation_policies [Enumerable<PreservationPolicy>] the list of preservation policies
  #   which the newly created endpoints implement.
  # @return [Array<ArchiveEndpoint>] the ArchiveEndpoint list for the archive endpoints defined in the config (all
  #   entries, including any entries that may have been seeded already)
  # @note this adds new entries from the config, and leaves existing entries alone, but won't delete anything.
  # TODO: figure out deletion/update based on config?
  def self.seed_archive_endpoints_from_config(preservation_policies)
    return unless Settings.archive_endpoints
    Settings.archive_endpoints.map do |endpoint_name, endpoint_config|
      find_or_create_by!(endpoint_name: endpoint_name.to_s) do |endpoint|
        endpoint.endpoint_node = endpoint_config.endpoint_node
        endpoint.storage_location = endpoint_config.storage_location
        endpoint.preservation_policies = preservation_policies
        endpoint.delivery_class = delivery_classes[endpoint_config.delivery_class.constantize]
      end
    end
  end
end
