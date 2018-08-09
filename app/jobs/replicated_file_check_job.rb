# Confirms existence of ZippedMoabVersion on a zip endpoint.
# TODO: but should actually probably confirm that a CompleteMoab is fully/properly replicated
# Confirms the MD5 checksum matches in database and s3.
# Usage info:
# ReplicatedFileCheck.set(queue: :endpoint_check_us_west_2).perform_later(cm)
# ReplicatedFileCheck.set(queue: :endpoint_check_us_east_1).perform_later(cm)
class ReplicatedFileCheckJob < ApplicationJob
  # This queue is never expected to be used.
  queue_as :override_this_queue
  delegate :check_child_zip_part_attributes, to: Audit::CatalogToArchive
  delegate :check_aws_replicated_zipped_moab_version, to: PreservationCatalog::S3::Audit

  # @param [ZippedMoabVersion] verify that the zip exists on the endpoint
  def perform(zmv)
    # TODO: this job should maybe do the whole PO2R, not just "little C2A" (seeing if a specific
    # druid zip version is on an zip endpoint).  prob should take druid or PreservedObject?
    return unless check_child_zip_part_attributes(zmv)
    check_aws_replicated_zipped_moab_version(zmv)
  end
end
