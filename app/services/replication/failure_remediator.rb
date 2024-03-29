# frozen_string_literal: true

module Replication
  # Remediates catalog entries, e.g., prunes failed replication records
  # Currently this is only called from rake.
  class FailureRemediator
    def self.prune_replication_failures(druid:, version:, verify_expiration: true)
      new(druid: druid, version: version, verify_expiration: verify_expiration).prune_replication_failures
    end

    def initialize(druid:, version:, verify_expiration:)
      @druid = druid
      @version = version
      @verify_expiration = verify_expiration
    end

    # prunes ZipParts and ZippedMoabVersion from database for any ZippedMoabVersions that have replication errors for
    #   the druid and version (so remediation can then be kicked off with PreservedObject.create_zipped_moab_versions!)
    def prune_replication_failures
      zipped_moab_versions_with_errors.map do |zipped_moab_version, audit_results|
        zip_parts = zipped_moab_version.zip_parts
        Rails.logger.info(
          "Replication failure error(s) found with #{druid} (v#{version}): #{audit_results.error_results}\n" \
          "Destroying zip parts (#{zip_parts.pluck(:id)}) and zipped moab version (#{zipped_moab_version.id})"
        )

        ApplicationRecord.transaction do
          # NOTE: ZipPart instances must be destroyed _before_ the ZippedMoabVersion
          zip_parts.destroy_all
          zipped_moab_version.destroy
        end

        [zipped_moab_version.version, zipped_moab_version.zip_endpoint.endpoint_name]
      end
    end

    private

    attr_reader :druid, :version, :verify_expiration

    delegate :check_child_zip_part_attributes, to: Audit::ReplicationSupport

    def preserved_object
      PreservedObject.find_by(druid: druid)
    end

    def zip_cache_expiry_timestamp
      Settings.zip_cache_expiry_time.to_i.minutes.ago
    end

    def zipped_moab_versions_beyond_expiry
      return preserved_object.zipped_moab_versions.where(version: version, created_at: ..zip_cache_expiry_timestamp) if verify_expiration

      preserved_object.zipped_moab_versions.where(version: version)
    end

    def zipped_moab_versions_with_errors
      zipped_moab_versions_beyond_expiry.to_a.filter_map do |zipped_moab_version|
        audit_results = empty_audit_results(zipped_moab_version)
        # when Audit::ReplicationSupport.check_child_zip_part_attributes() returns true, we have ZipParts for the
        #   ZippedMoabVersion, so continue to the next check
        next [zipped_moab_version, audit_results] unless check_child_zip_part_attributes(zipped_moab_version, audit_results)

        # S3Audit.check_replicated_zipped_moab_version creates audit_results.error_results if problem with existence or
        #   checksum of replicated ZipPart files
        endpoint_audit_class_for(zipped_moab_version).check_replicated_zipped_moab_version(zipped_moab_version, audit_results, true)
        next if audit_results.error_results.empty?

        [zipped_moab_version, audit_results]
      end
    end

    def empty_audit_results(zipped_moab_version)
      Audit::Results.new(druid: druid, actual_version: version, moab_storage_root: zipped_moab_version.zip_endpoint)
    end

    def endpoint_audit_class_for(zipped_moab_version)
      zipped_moab_version.zip_endpoint.audit_class
    end
  end
end
