module PreservationCatalog
  module S3
    # Methods for auditing checking the state of a ZippedMoabVersion on an S3 endpoint.  Requires that AWS credentials
    # are available in the environment.  At the time of this comment, only running queue workers will have proper creds
    # loaded.
    class Audit
      class << self
        delegate :bucket, :bucket_name, to: ::PreservationCatalog::S3

        private

        def add_part_not_found_result(results, part)
          results.add_result(
            AuditResults::ZIP_PART_NOT_FOUND,
            endpoint_name: part.zipped_moab_version.zip_endpoint.endpoint_name,
            s3_key: part.s3_key,
            bucket_name: bucket_name
          )
        end

        def add_checksum_mismatch_result(results, part, replicated_checksum)
          results.add_result(
            AuditResults::ZIP_PART_CHECKSUM_MISMATCH,
            endpoint_name: part.zipped_moab_version.zip_endpoint.endpoint_name,
            s3_key: part.s3_key,
            md5: part.md5,
            replicated_checksum: replicated_checksum,
            bucket_name: bucket_name
          )
        end

        def check_existence(results, aws_s3_object, part)
          if aws_s3_object.exists?
            part.update(last_existence_check: Time.zone.now)
            true
          else
            # TODO: honeybadger alert for this, but keep going
            add_part_not_found_result(results, part)
            part.update(status: 'not_found', last_existence_check: Time.zone.now)
            false
          end
        end

        def compare_checksum_metadata(results, aws_s3_object, part)
          # NOTE: no checksum computation is happening here (neither on our side, nor on AWS's).  we're just comparing
          # the checksum we have stored with the checksum we asked AWS to store.  we really don't expect any drift, but
          # we're here, and it's a cheap check to do, and it'd be weird if they differed, so why not?
          # TODO: in a later work cycle, we'd like to spot check some cloud archives: that is, pull the zip down,
          # re-compute the checksum for the retrieved zip, and make sure it matches what we stored.
          replicated_checksum = replicated_checksum(aws_s3_object)
          if part.md5 == replicated_checksum
            part.update(last_checksum_validation: Time.zone.now)
            true
          else
            # TODO: honeybadger alert for this, but keep going
            add_checksum_mismatch_result(results, part, replicated_checksum)
            part.update(status: 'replicated_checksum_mismatch', last_checksum_validation: Time.zone.now)
            false
          end
        end
      end

      # TODO: make this more object oriented, init w/ results, make everything instance
      # methods, just init and call check_aws_replicated_zipped_moab_version
      #
      # @param [ZippedMoabVersion] zmv
      # @param [AuditResults] results
      def self.check_aws_replicated_zipped_moab_version(zmv, results)
        zmv.zip_parts.where.not(status: :unreplicated).each do |part|
          aws_s3_object = bucket.object(part.s3_key)
          next unless check_existence(results, aws_s3_object, part)
          next unless compare_checksum_metadata(results, aws_s3_object, part)
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
