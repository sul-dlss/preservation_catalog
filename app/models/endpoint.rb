##
# Metadata about a Moab storage root (a POSIX file system which contains Moab objects).
# TODO: rename to... OnlineEndpoint?  LocalMoabStorageRoot?
# TODO: remove the old description (leaving while things are being refactored)
class Endpoint < ApplicationRecord
  has_many :preserved_copies, dependent: :restrict_with_exception
  has_and_belongs_to_many :preservation_policies

  # @note Hash values cannot be modified without migrating any associated persisted data.
  # @see [enum docs] http://api.rubyonrails.org/classes/ActiveRecord/Enum.html
  # TODO: deprecated, remove this field (and drop DB col) once this has transitioned to ArchiveEndpoint
  enum delivery_class: {
    S3WestDeliveryJob => 1,
    S3EastDeliveryJob => 2
  }

  validates :endpoint_name, presence: true, uniqueness: true
  validates :endpoint_node, presence: true
  validates :storage_location, presence: true

  # Use a queue to validate PreservedCopy objects
  def validate_expired_checksums!
    pcs = preserved_copies.fixity_check_expired
    Rails.logger.info "Endpoint #{id} (#{endpoint_name}), # of preserved_copies to be checksum validated: #{pcs.count}"
    pcs.find_each { |pc| ChecksumValidationJob.perform_later(pc) }
  end

  # Iterates over the storage roots enumerated in settings, creating an Endpoint for each if it doesn't already exist.
  # @param preservation_policies [Enumerable<PreservationPolicy>] the list of preservation policies
  #   which any newly created endpoints implement.
  # @return [Array<Endpoint>] the Endpoint list for the local storage roots defined in the config (all entries,
  #   including any entries that may have been seeded already)
  # @note this adds new entries from the config, and leaves existing entries alone, but won't delete anything.
  # TODO: figure out deletion/update based on config?
  def self.seed_storage_root_endpoints_from_config(preservation_policies)
    HostSettings.storage_roots.map do |storage_root_name, storage_root_location|
      find_or_create_by!(endpoint_name: storage_root_name.to_s) do |endpoint|
        endpoint.endpoint_node = Settings.endpoints.storage_root_defaults.endpoint_node
        endpoint.storage_location = File.join(storage_root_location, Settings.moab.storage_trunk)
        endpoint.preservation_policies = preservation_policies
      end
    end
  end
end
