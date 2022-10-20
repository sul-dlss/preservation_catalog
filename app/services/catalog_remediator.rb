# frozen_string_literal: true

# Remediates catalog entries, e.g., failed replication records
class CatalogRemediator
  def self.prune_replication_failures(druid:, version:)
    new(druid: druid, version: version).prune_replication_failures
  end

  def initialize(druid:, version:)
    @druid = druid
    @version = version
  end

  def prune_replication_failures
    zipped_moab_versions_with_errors.map do |zipped_moab_version, audit_results|
      zip_parts = zipped_moab_version.zip_parts
      Rails.logger.info(
        "Replication failure error(s) found with #{druid} (v#{version}): #{audit_results.error_results}\n" \
        "Destroying zip parts (#{zip_parts.pluck(:id)}) and zipped moab version (#{zipped_moab_version.id})"
      )

      ApplicationRecord.transaction do
        # NOTE: The order here matters! ZipPart instances must be destroyed before the ZippedMoabVersion
        zip_parts.destroy_all
        zipped_moab_version.destroy
      end

      [zipped_moab_version.version, zipped_moab_version.zip_endpoint.endpoint_name]
    end
  end

  private

  attr_reader :druid, :version

  delegate :check_child_zip_part_attributes, to: Audit::CatalogToArchive

  def preserved_object
    PreservedObject.find_by(druid: druid)
  end

  def zip_cache_expiry_timestamp
    Settings.zip_cache_expiry_time.to_i.minutes.ago
  end

  def zipped_moab_versions_beyond_expiry
    preserved_object.zipped_moab_versions.where(version: version, created_at: ..zip_cache_expiry_timestamp)
  end

  def zipped_moab_versions_with_errors
    zipped_moab_versions_beyond_expiry.to_a.filter_map do |zipped_moab_version|
      audit_results = audit_results_for(zipped_moab_version)
      # If this check returns false, it indicates a lack of zip parts, in which
      # case we still want to delete the ZMV, so short-circuit the rest of the
      # block
      next [zipped_moab_version, audit_results] unless check_child_zip_part_attributes(zipped_moab_version, audit_results)

      endpoint_audit_class_for(zipped_moab_version).check_replicated_zipped_moab_version(zipped_moab_version, audit_results, true)
      next if audit_results.error_results.empty?

      [zipped_moab_version, audit_results]
    end
  end

  def audit_results_for(zipped_moab_version)
    AuditResults.new(druid: druid, actual_version: version, moab_storage_root: zipped_moab_version.zip_endpoint)
  end

  def endpoint_audit_class_for(zipped_moab_version)
    zipped_moab_version.zip_endpoint.audit_class
  end
end
