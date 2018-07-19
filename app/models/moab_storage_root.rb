##
# Metadata about a Moab storage root (a POSIX file system which contains Moab objects).
class MoabStorageRoot < ApplicationRecord
  has_many :preserved_copies, dependent: :restrict_with_exception
  has_and_belongs_to_many :preservation_policies

  validates :name, presence: true, uniqueness: true
  validates :storage_location, presence: true

  # Use a queue to validate PreservedCopy objects
  def validate_expired_checksums!
    pcs = preserved_copies.fixity_check_expired
    Rails.logger.info "MoabStorageRoot #{id} (#{name}), # of preserved_copies to be checksum validated: #{pcs.count}"
    pcs.find_each { |pc| ChecksumValidationJob.perform_later(pc) }
  end

  # Iterates over the storage roots enumerated in settings, creating a MoabStorageRoot for
  #   each if it doesn't already exist.
  # @param preservation_policies [Enumerable<PreservationPolicy>] the list of preservation policies
  #   which any newly created moab_storage_roots implement.
  # @return [Array<MoabStorageRoot>] MoabStorageRoots for each storage root defined in the config (all entries,
  #   including any entries that may have been seeded already)
  # @note this adds new entries from the config, and leaves existing entries alone, but won't delete anything.
  # TODO: figure out deletion/update based on config?
  def self.seed_moab_storage_roots_from_config(preservation_policies)
    HostSettings.storage_roots.map do |storage_root_name, storage_root_location|
      find_or_create_by!(name: storage_root_name.to_s) do |sr|
        sr.storage_location = File.join(storage_root_location, Settings.moab.storage_trunk)
        sr.preservation_policies = preservation_policies
      end
    end
  end
end