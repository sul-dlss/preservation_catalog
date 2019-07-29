# frozen_string_literal: true

# Confirms a CompleteMoab has all versions/parts replicated for each of its target endpoints.
# @note Enqueues a check per endpoint
# @example usage
#   MoabReplicationAuditJob.perform_later(cm)
class MoabReplicationAuditJob < ApplicationJob
  queue_as :moab_replication_audit

  # @param [CompleteMoab] verify that the zip exists on the endpoint
  def perform(complete_moab)
    backfill_missing_zmvs(complete_moab)
    ZipEndpoint
      .includes(:zipped_moab_versions)
      .where(zipped_moab_versions: { complete_moab: complete_moab }).each do |endpoint|
        PartReplicationAuditJob.perform_later(complete_moab, endpoint)
      end
    complete_moab.update(last_archive_audit: Time.current)
  end

  private

  def backfill_missing_zmvs(complete_moab)
    return unless Settings.replication.audit_should_backfill
    zmvs = complete_moab.create_zipped_moab_versions!
    return if zmvs.empty?
    Audit::CatalogToArchive.logger.warn(
      "#{self.class}: #{complete_moab.preserved_object.druid} backfilled #{zmvs.count} ZippedMoabVersions: #{format_zmvs(zmvs)}"
    )
  end

  # @return [String] a potentially large message
  def format_zmvs(zmvs)
    zmvs.map { |bz| "#{bz.version} to #{bz.zip_endpoint.endpoint_name}" }.sort.join("; ")
  end
end
