##
# Metadata about a Moab storage root (a POSIX file system which contains Moab objects).
class MoabStorageRoot < ApplicationRecord
  has_many :complete_moabs, dependent: :restrict_with_exception
  has_and_belongs_to_many :preservation_policies

  validates :name, presence: true, uniqueness: true
  validates :storage_location, presence: true

  # Use a queue to validate CompleteMoab objects
  def validate_expired_checksums!
    cms = complete_moabs.fixity_check_expired
    Rails.logger.info "MoabStorageRoot #{id} (#{name}), # of complete_moabs to be checksum validated: #{cms.count}"
    cms.find_each { |cm| ChecksumValidationJob.perform_later(cm) }
  end

  # Use a queue to check all associated CompleteMoab objects for C2M
  def c2m_check!(last_checked_b4_date = Time.current)
    complete_moabs.least_recent_version_audit(last_checked_b4_date).find_each do |cm|
      CatalogToMoabJob.new(cm, storage_location).perform_later
    end
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
