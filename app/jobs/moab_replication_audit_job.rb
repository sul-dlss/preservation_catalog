# Confirms that a CompleteMoab is fully/properly replicated to all target zip endpoints.
# Usage info:
# ReplicatedFileCheck.set(queue: :endpoint_check_us_west_2).perform_later(cm)
# ReplicatedFileCheck.set(queue: :endpoint_check_us_east_1).perform_later(cm)
class MoabReplicationAuditJob < ApplicationJob
  # This queue is never expected to be used.
  queue_as :override_this_queue
  delegate :check_child_zip_part_attributes, to: Audit::CatalogToArchive
  delegate :check_aws_replicated_zipped_moab_version, to: PreservationCatalog::S3::Audit
  delegate :logger, to: Audit::CatalogToArchive

  # @param [ZippedMoabVersion] verify that the zip exists on the endpoint
  def perform(complete_moab)
    # TODO: will also need to create a CompleteMoab.archive_check_expired scope, use that
    # to queue jobs for this worker.

    backfilled_zmvs = complete_moab.create_zipped_moab_versions!
    unless backfilled_zmvs.empty?
      prefix = "#{complete_moab.preserved_object.druid} #{complete_moab.inspect}"
      msg = "#{prefix}: backfilled unreplicated zipped_moab_versions: #{backfilled_zmvs.inspect}"
      logger.warn(msg)
    end

    complete_moab.zipped_moab_versions.each do |zmv|
      next unless check_child_zip_part_attributes(zmv)
      check_aws_replicated_zipped_moab_version(zmv)
    end
  end
end
