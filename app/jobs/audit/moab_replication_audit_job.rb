# frozen_string_literal: true

module Audit
  # Checks whether a PreservedObject has all versions/parts replicated for each of its target endpoints.
  # @note Enqueues a check per endpoint
  class MoabReplicationAuditJob < ApplicationJob
    queue_as :moab_replication_audit
    delegate :logger, to: Audit::ReplicationSupport

    include UniqueJob

    # @param [PreservedObject] for which to verify presence of the archive zips we think we've replicated (and possibly backfill those we haven't)
    def perform(preserved_object)
      return if backfill_missing_zipped_moab_versions(preserved_object)

      results = Audit::Replication.results(preserved_object)
      results.each { |audit_results| AuditResultsReporter.report_results(audit_results: audit_results, logger: logger) }
    end

    private

    def backfill_missing_zipped_moab_versions(preserved_object)
      return false unless Settings.replication.audit_should_backfill
      zipped_moab_versions = preserved_object.create_zipped_moab_versions!
      return false if zipped_moab_versions.blank?
      Audit::ReplicationSupport.logger.warn(
        "#{self.class}: #{preserved_object.druid} backfilled #{zipped_moab_versions.count} ZippedMoabVersions: #{format_zmvs(zipped_moab_versions)}"
      )
      true
    end

    # @return [String] a potentially large message
    def format_zmvs(zmvs)
      zmvs.map { |bz| "#{bz.version} to #{bz.zip_endpoint.endpoint_name}" }.sort.join('; ')
    end
  end
end
