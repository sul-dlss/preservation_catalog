# frozen_string_literal: true

##
# CompleteMoab represents a concrete instance of a PreservedObject across ALL versions, in physical storage.
class CompleteMoab < ApplicationRecord
  # @note Hash values cannot be modified without migrating any associated persisted data.
  # @see [enum docs] http://api.rubyonrails.org/classes/ActiveRecord/Enum.html
  enum status: {
    'ok' => 0,
    'invalid_moab' => 1,
    'invalid_checksum' => 2,
    'online_moab_not_found' => 3,
    'unexpected_version_on_storage' => 4,
    'validity_unknown' => 6
  }

  after_create :create_zipped_moab_versions!
  after_update :create_zipped_moab_versions!, if: :saved_change_to_version? # an ActiveRecord dynamic method
  after_save :validate_checksums!, if: proc { |cm| cm.saved_change_to_status? && cm.validity_unknown? }

  belongs_to :preserved_object, inverse_of: :complete_moabs
  belongs_to :moab_storage_root, inverse_of: :complete_moabs
  has_many :zipped_moab_versions, dependent: :restrict_with_exception, inverse_of: :complete_moab

  delegate :s3_key, to: :druid_version_zip

  validates :moab_storage_root, :preserved_object, :status, :version, presence: true
  # NOTE: size here is approximate and not used for fixity checking
  validates :size, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :by_druid, lambda { |druid|
    joins(:preserved_object).where(preserved_objects: { druid: druid })
  }

  scope :least_recent_version_audit, lambda { |last_checked_b4_date|
    where('last_version_audit IS NULL or last_version_audit < ?', normalize_date(last_checked_b4_date))
  }

  scope :fixity_check_expired, lambda {
    joins(:preserved_object)
      .joins(
        'INNER JOIN preservation_policies'\
        ' ON preservation_policies.id = preserved_objects.preservation_policy_id'\
        ' AND (last_checksum_validation + (fixity_ttl * INTERVAL \'1 SECOND\')) < CURRENT_TIMESTAMP'\
        ' OR last_checksum_validation IS NULL'
      )
  }

  scope :archive_check_expired, lambda {
    joins(:preserved_object)
      .joins(
        'INNER JOIN preservation_policies'\
        ' ON preservation_policies.id = preserved_objects.preservation_policy_id'\
        ' AND (last_archive_audit + (archive_ttl * INTERVAL \'1 SECOND\')) < CURRENT_TIMESTAMP'\
        ' OR last_archive_audit IS NULL'
      )
  }

  # This is where we make sure we have ZMV rows for all needed ZipEndpoints and versions.
  # Endpoints may have been added, so we must check all dimensions.
  # For *this* and *previous* versions, create any ZippedMoabVersion records which don't yet exist for
  # ZipEndpoints on the parent PreservedObject's PreservationPolicy.
  # @return [Array<ZippedMoabVersion>] the ZippedMoabVersion records that were created
  # @todo potential optimization: fold N which_need_archive_copy queries into one new query
  def create_zipped_moab_versions!
    params = (1..version).map do |v|
      ZipEndpoint.which_need_archive_copy(preserved_object.druid, v).map { |zep| { version: v, zip_endpoint: zep } }
    end.flatten.compact.uniq
    zipped_moab_versions.create!(params)
  end

  # Send to asynchronous checksum validation pipeline
  def validate_checksums!
    ChecksumValidationJob.perform_later(self)
  end

  # Queue a job that will check to see whether this CompleteMoab has been
  # fully replicated to all target ZipEndpoints
  def audit_moab_version_replication!
    MoabReplicationAuditJob.perform_later(self)
  end

  def druid_version_zip
    @druid_version_zip ||= DruidVersionZip.new(preserved_object.druid, version)
  end

  def replicatable_status?
    ok?
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

  private_class_method def self.normalize_date(timestamp)
    return timestamp if timestamp.is_a?(Time) || timestamp.is_a?(ActiveSupport::TimeWithZone)
    Time.parse(timestamp).utc
  end

  # Sort the given relation by last_version_audit, nulls first.
  def self.order_last_version_audit(active_record_relation)
    # possibly non-obvious: IS NOT NULL evaluates to 0 for nulls and 1 for non-nulls; thus, this
    # sorts nulls (0) before non-nulls (1), and non-nulls are then sorted by last_version_audit.
    # standard SQL doesn't have a NULLS FIRST sort built in.
    active_record_relation.order('last_version_audit IS NOT NULL, last_version_audit ASC')
  end

  # Sort the given relation by last_checksum_validation, nulls first.
  def self.order_fixity_check_expired(active_record_relation)
    # possibly non-obvious: IS NOT NULL evaluates to 0 for nulls and 1 for non-nulls; thus, this
    # sorts nulls (0) before non-nulls (1), and non-nulls are then sorted by last_checksum_validation.
    # standard SQL doesn't have a NULLS FIRST sort built in.
    active_record_relation.order('last_checksum_validation IS NOT NULL, last_checksum_validation ASC')
  end
end
