# frozen_string_literal: true

# Confirms that a PreservedObject is fully/properly replicated to ONE target endpoint.
# The endpoint is used to build the queue name which much be serviced by a worker with
# corresponding (AWS) credentials.
# @example usage
#  PartReplicationAuditJob.perform_later(po, endpoint)
class PartReplicationAuditJob < ApplicationJob
  queue_as { "part_audit_#{arguments.second.endpoint_name}" }
  delegate :check_child_zip_part_attributes, :logger, to: Audit::CatalogToArchive

  include UniqueJob

  # @param [PreservedObject] preserved_object
  # @param [ZipEndpoint] zip_endpoint endpoint being checked
  def perform(preserved_object, zip_endpoint)
    results = new_results
    preserved_object.zipped_moab_versions.where(zip_endpoint: zip_endpoint).each do |zmv|
      next unless check_child_zip_part_attributes(zmv, results)
      zip_endpoint.audit_class.check_replicated_zipped_moab_version(zmv, results)
    end
    AuditResultsReporter.report_results(audit_results: results, logger: logger)
  end

  private

  def new_results
    AuditResults.new(druid: arguments.first.druid, moab_storage_root: arguments.second, check_name: 'PartReplicationAuditJob')
  end
end
