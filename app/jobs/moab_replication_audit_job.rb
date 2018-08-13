# Confirms that a CompleteMoab is fully/properly replicated to all target zip endpoints.
# Usage info:
# ReplicatedFileCheck.set(queue: :endpoint_check_us_west_2).perform_later(cm)
# ReplicatedFileCheck.set(queue: :endpoint_check_us_east_1).perform_later(cm)
class MoabReplicationAuditJob < ApplicationJob
  queue_as :moab_replication_audit
  delegate :check_child_zip_part_attributes, to: Audit::CatalogToArchive
  delegate :check_aws_replicated_zipped_moab_version, to: PreservationCatalog::S3::Audit
  delegate :logger, to: Audit::CatalogToArchive

  # @param [ZippedMoabVersion] verify that the zip exists on the endpoint
  def perform(complete_moab)
    druid = complete_moab.preserved_object.druid

    results = AuditResults.new(druid, nil, complete_moab.moab_storage_root, "MoabReplicationAuditJob")
    # TODO: will also need to create a CompleteMoab.archive_check_expired scope, use that
    # to queue jobs for this worker.

    backfilled_zmvs = complete_moab.create_zipped_moab_versions!
    unless backfilled_zmvs.empty?
      results.add_result(
        AuditResults::ZMV_BACKFILL,
        version_endpoint_pairs: format_backfilled_zmvs(backfilled_zmvs)
      )
    end

    complete_moab.zipped_moab_versions.each do |zmv|
      next unless check_child_zip_part_attributes(zmv, results)
      check_aws_replicated_zipped_moab_version(zmv, results)
    end

    # TODO: will need to test call to this once no longer integration testing what gets logged, make
    # sure report_results, gets expected logger instance (from C2A)
    results.report_results(logger)
  end

  private

  def format_backfilled_zmvs(backfilled_zmvs)
    backfilled_zmvs.map { |bz| "#{bz.version} to #{bz.zip_endpoint.endpoint_name}" }.sort.join("; ")
  end
end
