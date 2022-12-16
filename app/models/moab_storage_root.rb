# frozen_string_literal: true

##
# Metadata about a Moab storage root (a POSIX file system which contains Moab objects).
class MoabStorageRoot < ApplicationRecord
  has_many :moab_records, dependent: :restrict_with_exception
  has_many :migrated_moabs, class_name: 'MoabRecord', foreign_key: :from_moab_storage_root_id
  has_many :preserved_objects, through: :moab_records

  validates :name, presence: true, uniqueness: true
  validates :storage_location, presence: true, uniqueness: true

  scope :preserved_objects, lambda {
    joins(moab_records: [:preserved_object])
  }

  # Use a queue to validate MoabRecord objects
  def validate_expired_checksums!
    moab_recs = moab_records.fixity_check_expired
    Rails.logger.info "MoabStorageRoot #{id} (#{name}), # of moab_records to be checksum validated: #{moab_recs.count}"
    moab_recs.find_each(&:validate_checksums!)
  end

  # Use a queue to check all associated MoabRecord objects for C2M
  def c2m_check!(last_checked_b4_date = Time.current)
    moab_records.version_audit_expired(last_checked_b4_date).find_each do |moab_rec|
      CatalogToMoabJob.perform_later(moab_rec)
    end
  end

  # Use a queue to ensure each druid on this root's directory is in the catalog database
  def m2c_check!
    MoabOnStorage::StorageDirectory.find_moab_paths(storage_location) do |druid, _path, _match|
      MoabToCatalogJob.perform_later(self, druid)
    end
  end

  def to_s
    name
  end

  # Iterates over the storage roots enumerated in settings, creating a MoabStorageRoot for
  # each if it doesn't already exist.  Besides db/seeds.rb, this should be used rarely, if at all.
  # @return [Array<MoabStorageRoot>] MoabStorageRoots for each one defined in the config (found or created)
  # @note this adds new entries from the config, and leaves existing entries alone, but won't delete anything.
  def self.seed_from_config
    Settings.storage_root_map.default.each do |storage_root_name, storage_root_location|
      find_or_create_by!(name: storage_root_name.to_s) do |sr|
        sr.storage_location = File.join(storage_root_location, Settings.moab.storage_trunk)
      end
    end
  end
end
