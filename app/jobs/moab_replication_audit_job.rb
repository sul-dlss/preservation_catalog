# frozen_string_literal: true

# Checks whether a PreservedObject has all versions/parts replicated for each of its target endpoints.
# @note Enqueues a check per endpoint
# @example usage
#   MoabReplicationAuditJob.perform_later(preserved_object)
class MoabReplicationAuditJob < ApplicationJob
  queue_as :moab_replication_audit

  include UniqueJob

  # @param [PreservedObject] for which to verify presence of the archive zips we think we've replicated (and possibly backfill those we haven't)
  def perform(preserved_object)
    return if backfill_missing_zipped_moab_versions(preserved_object)

    ZipEndpoint
      .includes(:zipped_moab_versions)
      .where(zipped_moab_versions: { preserved_object: preserved_object }).each do |endpoint|
        PartReplicationAuditJob.perform_later(preserved_object, endpoint)
      end
    preserved_object.update(last_archive_audit: Time.current)
  end

  private

  def backfill_missing_zipped_moab_versions(preserved_object)
    return false unless Settings.replication.audit_should_backfill
    zipped_moab_versions = preserved_object.create_zipped_moab_versions!
    return false if zipped_moab_versions.empty?
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
