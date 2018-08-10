module PreservationCatalog
  module S3
    # Methods for auditing checking the state of a ZippedMoabVersion on an S3 endpoint.  Requires that AWS credentials
    # are available in the environment.  At the time of this comment, only running queue workers will have proper creds
    # loaded.
    class Audit
      class << self
        delegate :bucket, :bucket_name, to: ::PreservationCatalog::S3
        delegate :logger, to: ::Audit::CatalogToArchive
      end

      def self.check_aws_replicated_zipped_moab_version(zmv)
        zmv.zip_parts.where.not(status: :unreplicated).each do |part|
          aws_s3_object = bucket.object(part.s3_key)
          if aws_s3_object.exists?
            part.update(last_existence_check: Time.zone.now)
          else
            logger.error("Archival Preserved Copy: #{zmv.inspect} #{part.inspect} was not found on #{bucket_name}.")
            part.update(status: 'not_found', last_existence_check: Time.zone.now)
            next
          end

          # NOTE: no checksum computation is happening here (neither on our side, nor on AWS's).  we're just comparing
          # the checksum we have stored with the checksum we asked AWS to store.  we really don't expect any drift, but
          # we're here, and it's a cheap check to do, and it'd be weird if they differed, so why not?
          # TODO: in a later work cycle, we'd like to spot check some cloud archives: that is, pull the zip down,
          # re-compute the checksum for the retrieved zip, and make sure it matches what we stored.
          replicated_checksum = replicated_checksum(aws_s3_object)
          if part.md5 == replicated_checksum
            part.update(last_checksum_validation: Time.zone.now)
          else
            logger.error("Stored checksum(#{part.md5}) doesn't match the replicated checksum(#{replicated_checksum}).")
            part.update(status: 'replicated_checksum_mismatch', last_checksum_validation: Time.zone.now)
            next
          end

          part.ok!
        end
      end

      # @param [Aws::S3::Object]
      # @return [String] MD5
      def self.replicated_checksum(aws_s3_object)
        aws_s3_object.metadata["checksum_md5"]
      end
    end
  end
end
