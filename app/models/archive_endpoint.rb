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

  # for the given druid, which archive endpoints should have archive copies?
  scope :archive_targets, lambda { |druid|
    joins(preservation_policies: [:preserved_objects]).where(preserved_objects: { druid: druid })
  }

  # TODO: straight port of the scope from the old Endpoint class
  scope :which_need_archive_copy, lambda { |druid, version|
    # testing indicates that the Arel::Table#eq will cast the input to the appropriate type for us.  i didn't
    # didn't see that documented, so i'm casting version.to_i to be safe (since we're not using the usual bind
    # variable machinery).  just trying to be extra cautious about injection attacks.  we shouldn't have to
    # worry about druid, since it gets passed via the usual ActiveRecord bind var machinery.
    apc_table = ArchivePreservedCopy.arel_table
    aep_table = ArchiveEndpoint.arel_table
    endpoint_has_pres_copy_subquery =
      ArchivePreservedCopy.where(
        apc_table[:archive_endpoint_id].eq(aep_table[:id])
          .and(apc_table[:version].eq(version.to_i))
      ).exists

    archive_targets(druid).where.not(endpoint_has_pres_copy_subquery)
  }

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
