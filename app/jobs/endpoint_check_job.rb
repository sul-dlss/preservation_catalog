# Confirms existence of PreservedCopy on an endpoint
# Notify ResultsRecorder, with success or failure of existence.
class EndpointCheckJob < ApplicationJob
  queue_as :endpoint_check
  delegate :bucket, :bucket_name, to: PreservationCatalog::S3

  # @param [PreservedCopy] verify that the archived preserved_copy exists on an endpoint
  def perform(preserved_copy)
    return if preserved_copy.status == PreservedCopy::UNREPLICATED_STATUS # FIXME: What to do covered in storytime
    aws_s3_object = bucket.object(preserved_copy.s3_key)
    if aws_s3_object.exists?
      stored_checksums = stored_checksums(preserved_copy)
      replicated_checksum = replicated_checksum(aws_s3_object)
      if stored_checksums.include?(replicated_checksum)
        preserved_copy.update_status(PreservedCopy::OK_STATUS)
        preserved_copy.update(last_checksum_validation: Time.zone.now)
      else
        preserved_copy.update_status(PreservedCopy::CHECKSUM_MISMATCH)
      end
    else
      preserved_copy.update_status(PreservedCopy::FILE_NOT_FOUND)
    end
    preserved_copy.save!
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
