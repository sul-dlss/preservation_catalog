# frozen_string_literal: true

module Audit
  # Job to audit replication for a PreservedObject
  class ReplicationAuditJob < ApplicationJob
    queue_as :moab_replication_audit
    delegate :logger, to: Audit::ReplicationSupport

    include UniqueJob

    def perform(preserved_object)
      @preserved_object = preserved_object

      preserved_object.populate_zipped_moab_versions!

      ::Replication::AuditService.call(preserved_object: preserved_object).each do |audit_results|
        AuditResultsReporter.report_results(audit_results: audit_results, logger: logger)
      end

      preserved_object.update!(last_archive_audit: Time.current)

      start_replication
    end

    attr_reader :preserved_object

    def start_replication
      return unless preserved_object.zipped_moab_versions.created.exists? || preserved_object.zipped_moab_versions.incomplete.exists?
      ::ReplicationJob.perform_later(preserved_object)
    end
  end
end
