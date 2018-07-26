# Confirms existence of CompleteMoab on a zip endpoint.
# Confirms the MD5 checksum matches in database and s3.
# Usage info:
# ReplicatedFileCheck.set(queue: :endpoint_check_us_west_2).perform_later(cm)
# ReplicatedFileCheck.set(queue: :endpoint_check_us_east_1).perform_later(cm)
class ReplicatedFileCheckJob < ApplicationJob
  # This queue is never expected to be used.
  queue_as :override_this_queue
  delegate :bucket, :bucket_name, to: PreservationCatalog::S3

  # @param [CompleteMoab] verify that the archived complete_moab exists on a zip endpoint
  def perform(complete_moab)
    if complete_moab.unreplicated?
      Rails.logger.error("#{complete_moab} should be replicated, but has a status of #{complete_moab.status}.")
      return
    end
    aws_s3_object = bucket.object(complete_moab.s3_key)
    stored_checksums = stored_checksums(complete_moab)
    replicated_checksum = replicated_checksum(aws_s3_object)
    unless aws_s3_object.exists?
      Rails.logger.error("Archival Complete Moab: #{complete_moab} was not found on #{bucket_name}.")
      complete_moab.replicated_copy_not_found!
      return
    end
    complete_moab.last_checksum_validation = Time.zone.now
    unless stored_checksums.include?(replicated_checksum)
      Rails.logger.error("Stored checksum(#{stored_checksums}) doesn't include the replicated checksum(#{replicated_checksum}).")
      complete_moab.invalid_checksum!
      return
    end
    complete_moab.ok!
  end

  # @param [CompleteMoab]
  # @return [Array<String>] MD5's
  def stored_checksums(complete_moab)
    complete_moab.zipped_moab_versions.map(&:zip_parts).flatten.map(&:md5)
  end

  # @param [Aws::S3::Object]
  # @return [String] MD5
  def replicated_checksum(aws_s3_object)
    aws_s3_object.metadata["checksum_md5"]
  end
end
