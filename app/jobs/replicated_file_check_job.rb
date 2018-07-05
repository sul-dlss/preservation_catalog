# Confirms existence of PreservedCopy on an endpoint.
# Confirms the MD5 checksum matches in database and s3.
# Usage info:
# ReplicatedFileCheck.set(queue: :endpoint_check_us_west_2).perform_later(pc)
# ReplicatedFileCheck.set(queue: :endpoint_check_us_east_1).perform_later(pc)
class ReplicatedFileCheckJob < ApplicationJob
  # This queue is never expected to be used.
  queue_as :override_this_queue
  delegate :bucket, :bucket_name, to: PreservationCatalog::S3

  # @param [PreservedCopy] verify that the archived preserved_copy exists on an endpoint
  def perform(preserved_copy)
    if preserved_copy.unreplicated?
      Rails.logger.error("#{preserved_copy} should be replicated, but has a status of #{preserved_copy.status}.")
      return
    end
    aws_s3_object = bucket.object(preserved_copy.s3_key)
    stored_checksums = stored_checksums(preserved_copy)
    replicated_checksum = replicated_checksum(aws_s3_object)
    unless aws_s3_object.exists?
      Rails.logger.error("Archival Preserved Copy: #{preserved_copy} was not found on #{bucket_name}.")
      preserved_copy.replicated_copy_not_found!
      return
    end
    preserved_copy.last_checksum_validation = Time.zone.now
    unless stored_checksums.include?(replicated_checksum)
      Rails.logger.error("Stored checksum(#{stored_checksums}) doesn't include the replicated checksum(#{replicated_checksum}).")
      preserved_copy.invalid_checksum!
      return
    end
    preserved_copy.ok!
  end

  # @param [PreservedCopy]
  # @return [Array<String>] MD5's
  def stored_checksums(preserved_copy)
    preserved_copy.zip_checksums.map(&:md5)
  end

  # @param [Aws::S3::Object]
  # @return [String] MD5
  def replicated_checksum(aws_s3_object)
    aws_s3_object.metadata["checksum_md5"]
  end
end
