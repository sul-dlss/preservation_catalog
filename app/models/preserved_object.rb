# frozen_string_literal: true

##
# PreservedObject represents a master record tying together all
# concrete copies of an object that is being preserved.  It does not
# represent a specific stored instance on a specific node, but aggregates
# those instances.
class PreservedObject < ApplicationRecord
  PREFIX_RE = /druid:/i

  # hook for creating archive zips is here and on MoabRecord, because version and current_version must be in sync, and
  # even though both fields will usually be updated together in a single transaction, one has to be updated first.  latter
  # of the two updates will actually trigger replication.
  after_update :create_zipped_moab_versions!, if: :saved_change_to_current_version? # an ActiveRecord dynamic method

  has_one :moab_record, dependent: :restrict_with_exception, autosave: true
  has_many :zipped_moab_versions, dependent: :restrict_with_exception, inverse_of: :preserved_object

  validates :druid,
            presence: true,
            uniqueness: true,
            length: { is: 11 },
            format: { with: /(?!#{PREFIX_RE})#{DruidTools::Druid.pattern}/ } # ?! group is a *negative* match
  validates :current_version, presence: true, numericality: { only_integer: true, greater_than: 0 }

  scope :without_moab_record, -> { where.missing(:moab_record) }

  scope :archive_check_expired, lambda {
    where(
      'last_archive_audit < (CURRENT_TIMESTAMP - (? * INTERVAL \'1 SECOND\')) OR last_archive_audit IS NULL',
      Settings.preservation_policy.archive_ttl
    )
  }

  # This is where we make sure we have ZMV rows for all needed ZipEndpoints and versions.
  # Endpoints may have been added, so we must check all dimensions.
  # For this and previous versions, create the ZippedMoabVersion records for the ZipEndpoints
  # that don't already have the given Moab version.
  # @return [Array<ZippedMoabVersion>, nil] the ZippedMoabVersion records that were created, or nil if no moabs were in a state allowing replication
  # @todo potential optimization: fold N which_need_archive_copy queries into one new query
  def create_zipped_moab_versions!
    storage_location = moab_replication_storage_location
    return nil unless storage_location

    params = (1..current_version).map do |v|
      ZipEndpoint.which_need_archive_copy(druid, v).map { |zep| { version: v, zip_endpoint: zep } }
    end.flatten.compact.uniq

    zipped_moab_versions.create!(params).tap do |zmvs|
      zmvs.pluck(:version).uniq.each { |version| Replication::ZipmakerJob.perform_later(druid, version, storage_location) }
    end
  end

  def as_json(*)
    super.except('id')
  end

  # Queue a job that will check to see whether this PreservedObject has been
  # fully replicated to all target ZipEndpoints
  def audit_moab_version_replication!
    Audit::MoabReplicationAuditJob.perform_later(self)
  end

  def total_size_of_moab_version(version)
    return 0 unless moab_record

    Replication::DruidVersionZip.new(druid, version, moab_record.moab_storage_root.storage_location).moab_version_size
  end

  # Number of PreservedObjects to audit on a daily basis.
  def self.daily_check_count
    PreservedObject.count / (Settings.preservation_policy.fixity_ttl / (60 * 60 * 24))
  end

  private

  # We need a specific copy of a moab from which to create the zip file(s) to send to the cloud.
  # Of those eligible for replication, use whichever was checksum validated most recently.
  # @return [String, nil] The storage location (storage_root/storage_trunk) where the Moab that should be replicated lives.
  def moab_replication_storage_location
    moabs_eligible_for_replication.joins(:moab_storage_root).order(last_checksum_validation: :desc).limit(1).pick(:storage_location)
  end

  # a moab is eligible for replication if its status is 'ok' and its version is up to date with the latest seen for the object
  def moabs_eligible_for_replication
    MoabRecord.joins(:preserved_object).where(preserved_object: self, moab_records: { status: 'ok', version: current_version })
  end
end
