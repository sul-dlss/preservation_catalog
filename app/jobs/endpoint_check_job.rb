# Confirms existence of PreservedCopy on an endpoint.
# Confirms the MD5 checksum matches in database and s3.
class EndpointCheckJob < ApplicationJob
  # This queue is never expected to be used. For example:
  # EndpointCheckJob.set(queue: :endpoint_check_us_west_2).perform_later(pc)
  # EndpointCheckJob.set(queue: :endpoint_check_us_east_1).perform_later(pc)
  queue_as :endpoint_check
  delegate :bucket, :bucket_name, to: PreservationCatalog::S3

  # @param [PreservedCopy] verify that the archived preserved_copy exists on an endpoint
  def perform(preserved_copy)
    return if preserved_copy.status == PreservedCopy::UNREPLICATED_STATUS # FIXME: storytime (Monday 07/02)
    aws_s3_object = bucket.object(preserved_copy.s3_key)
    stored_checksums = stored_checksums(preserved_copy)
    replicated_checksum = replicated_checksum(aws_s3_object)
    return preserved_copy.replicated_copy_not_found! unless aws_s3_object.exists?
    unless stored_checksums.include?(replicated_checksum)
      preserved_copy.update(last_checksum_validation: Time.zone.now)
      return preserved_copy.invalid_checksum!
    end
    preserved_copy.update(last_checksum_validation: Time.zone.now)
    preserved_copy.ok!
  end

  # returns array
  def stored_checksums(preserved_copy)
    preserved_copy.zip_checksums.map(&:md5)
  end

  # returns string
  def replicated_checksum(aws_s3_object)
    aws_s3_object.metadata["checksum_md5"]
  end
end
