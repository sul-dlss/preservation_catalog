# frozen_string_literal: true

##
# MoabRecord represents a concrete instance of a PreservedObject across ALL versions, in physical storage.
class MoabRecord < ApplicationRecord
  # @note Hash values cannot be modified without migrating any associated persisted data.
  # @see [enum docs] http://api.rubyonrails.org/classes/ActiveRecord/Enum.html
  enum :status, {
    'ok' => 0,
    'invalid_moab' => 1,
    'invalid_checksum' => 2,
    'moab_on_storage_not_found' => 3,
    'unexpected_version_on_storage' => 4,
    'validity_unknown' => 6
  }

  after_save :validate_checksums!, if: proc { |moab_record| moab_record.saved_change_to_status? && moab_record.validity_unknown? }

  # NOTE: Since Rails 5.0, belongs_to adds the presence validator automatically, and explicit presence validation
  #   is redundant (unless you explicitly set config.active_record.belongs_to_required_by_default to false, which we don't.)
  belongs_to :preserved_object, inverse_of: :moab_record
  belongs_to :moab_storage_root, inverse_of: :moab_records
  belongs_to :from_moab_storage_root, class_name: 'MoabStorageRoot', optional: true

  validates :status, :version, presence: true
  validates :preserved_object_id, uniqueness: true
  # NOTE: size here is approximate and not used for fixity checking
  validates :size, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :by_druid, lambda { |druid|
    joins(:preserved_object).where(preserved_objects: { druid: druid })
  }

  scope :by_storage_root, lambda { |moab_storage_root|
    joins(:moab_storage_root).where(moab_storage_root: moab_storage_root)
  }

  scope :version_audit_expired, lambda { |expired_date|
    where('last_version_audit IS NULL or last_version_audit < ?', normalize_date(expired_date))
  }

  scope :fixity_check_expired, lambda {
    where('last_checksum_validation < ? or last_checksum_validation IS NULL', Time.zone.now - Settings.preservation_policy.fixity_ttl.seconds)
  }

  # Send to asynchronous checksum validation pipeline
  def validate_checksums!
    Audit::ChecksumValidationJob.perform_later(self)
  end

  def update_audit_timestamps(moab_validated, version_audited)
    t = Time.current
    self.last_moab_validation = t if moab_validated
    self.last_version_audit = t if version_audited
  end

  # @param [Boolean] moab_validated whether validation has been run (regardless of result)
  # @param [Integer] new_version
  # @param [Integer] new_size is expected to be numeric if provided
  def upd_audstamps_version_size(moab_validated, new_version, new_size = nil)
    self.version = new_version
    self.size = new_size if new_size
    update_audit_timestamps(moab_validated, true)
  end

  def matches_po_current_version?
    version == preserved_object.current_version
  end

  # This method can be used to update the MoabRecord record in Preservation Catalog when the
  # corresponding Moab directory on the file system has moved from its old storage root to a new
  # one (e.g. when migrating off of old storage hardware in bulk, or when manually moving a Moab
  # that's growing to a storage root with more space).
  #
  # Sets status to 'validity_unknown' and clears validation details, under the assumption that
  # the moab moved across file systems, resulting in newly written bits and a need for revalidation.
  #
  # Like other update methods in this class, it leaves saving to the caller.
  #
  # @param [MoabStorageRoot] to_root the storage root to which the Moab's been moved on the file system
  # @return [MoabRecord] the instance on which the method was called
  def migrate_moab(to_root)
    self.from_moab_storage_root = moab_storage_root
    self.moab_storage_root = to_root
    self.status = 'validity_unknown' # an after_save hook watches for this status and queues CV
    self.status_details = nil
    self.last_moab_validation = nil
    self.last_checksum_validation = nil
    self.last_version_audit = nil
    self
  end

  def self.normalize_date(timestamp)
    return timestamp if timestamp.is_a?(Time) || timestamp.is_a?(ActiveSupport::TimeWithZone)
    Time.parse(timestamp).utc
  end

  # Sort the given relation by last_version_audit, nulls first.
  def self.order_last_version_audit(active_record_relation)
    # possibly non-obvious: IS NOT NULL evaluates to 0 for nulls and 1 for non-nulls; thus, this
    # sorts nulls (0) before non-nulls (1), and non-nulls are then sorted by last_version_audit.
    # standard SQL doesn't have a NULLS FIRST sort built in.
    active_record_relation.order(Arel.sql('last_version_audit IS NOT NULL, last_version_audit ASC'))
  end

  # Number of MoabRecords to validate on a daily basis.
  def self.daily_check_count
    MoabRecord.count / (Settings.preservation_policy.fixity_ttl / (60 * 60 * 24))
  end
end
