# frozen_string_literal: true

##
# PreservedObject represents a master record tying together all
# concrete copies of an object that is being preserved.  It does not
# represent a specific stored instance on a specific node, but aggregates
# those instances.
class PreservedObject < ApplicationRecord
  include PreservedObjectCalculations

  PREFIX_RE = /druid:/i

  # has_one :moab_record, dependent: :restrict_with_exception, autosave: true
  has_one :moab_storage_root, dependent: :restrict_with_exception, autosave: true
  has_many :zipped_moab_versions, dependent: :restrict_with_exception, inverse_of: :preserved_object

  validates :druid,
            presence: true,
            uniqueness: true,
            length: { is: 11 },
            format: { with: /(?!#{PREFIX_RE})#{DruidTools::Druid.pattern}/ } # ?! group is a *negative* match
  validates :current_version, presence: true, numericality: { only_integer: true, greater_than: 0 }

  scope :archive_check_expired, lambda {
    where(
      'last_archive_audit < (CURRENT_TIMESTAMP - (? * INTERVAL \'1 SECOND\')) OR last_archive_audit IS NULL',
      Settings.preservation_policy.archive_ttl
    )
  }

  # Creates ZippedMoabVersion for each version for each ZipEndpoint for which a ZippedMoabVersion does not already exist.
  # @return [Array<ZippedMoabVersion>] the ZippedMoabVersions that were created
  def populate_zipped_moab_versions!
    [].tap do |new_zipped_moab_versions|
      (1..current_version).each do |version|
        ZipEndpoint.find_each do |zip_endpoint|
          next if zipped_moab_versions.exists?(version: version, zip_endpoint: zip_endpoint)
          new_zipped_moab_versions << zipped_moab_versions.create!(version: version, zip_endpoint: zip_endpoint)
        end
      end
    end
  end

  # Queue a job that will check to see whether this PreservedObject has been
  # fully replicated to all target ZipEndpoints
  def audit_moab_version_replication!
    Audit::ReplicationAuditJob.perform_later(self)
  end

  # Number of PreservedObjects to audit on a daily basis.
  def self.daily_check_count
    PreservedObject.count / (Settings.preservation_policy.fixity_ttl / (60 * 60 * 24))
  end
end
