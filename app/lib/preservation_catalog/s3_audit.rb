# frozen_string_literal: true

module PreservationCatalog
  # Base class for AWS and IBM audit classes
  class S3Audit
    delegate :bucket_name, to: :s3_provider

    attr_reader :zmv, :results

    # @param [ZippedMoabVersion] the ZippedMoabVersion to check
    # @param [AuditResults] the AuditResults instance used to track findings for this audit run
    def initialize(zmv, results)
      @zmv = zmv
      @results = results
    end

    # convenience method for instantiating the audit class and running the check in one call
    def self.check_replicated_zipped_moab_version(zmv, results)
      new(zmv, results).check_replicated_zipped_moab_version
    end

    def check_replicated_zipped_moab_version
      zmv.zip_parts.where.not(status: :unreplicated).each do |part|
        s3_object = bucket.object(part.s3_key)
        next unless check_existence(s3_object, part)
        next unless compare_checksum_metadata(s3_object, part)

        part.ok!
      end
    end

    # @return [PreservationCatalog::Aws, PreservationCatalog::Ibm] class that will provide .configure, .bucket, and .bucket_name methods
    def s3_provider
      raise 'this method should be implemented by the child class'
    end

    private

    def bucket
      endpoint = zmv.zip_endpoint.endpoint_name
      s3_provider.configure(
        region: Settings.zip_endpoints[endpoint].region,
        access_key_id: Settings.zip_endpoints[endpoint].access_key_id,
        secret_access_key: Settings.zip_endpoints[endpoint].secret_access_key
      )
      s3_provider.bucket
    end

    # NOTE: no checksum computation is happening here (neither on our side, nor on cloud provider's).  we're just comparing
    # the checksum we have stored with the checksum we asked the cloud provider to store.  we really don't expect any drift, but
    # we're here, and it's a cheap check to do, and it'd be weird if they differed, so why not?
    # TODO: in a later work cycle, we'd like to spot check some cloud archives: that is, pull the zip down,
    # re-compute the checksum for the retrieved zip, and make sure it matches what we stored.
    def compare_checksum_metadata(s3_object, part)
      replicated_checksum = s3_object.metadata['checksum_md5']
      if part.md5 == replicated_checksum
        part.update(last_checksum_validation: Time.zone.now)
        true
      else
        results.add_result(
          AuditResults::ZIP_PART_CHECKSUM_MISMATCH,
          endpoint_name: part.zipped_moab_version.zip_endpoint.endpoint_name,
          s3_key: part.s3_key,
          md5: part.md5,
          replicated_checksum: replicated_checksum,
          bucket_name: bucket_name
        )
        part.update(status: 'replicated_checksum_mismatch', last_checksum_validation: Time.zone.now)
        false
      end
    end

    def check_existence(s3_object, part)
      if s3_object.exists?
        part.update(last_existence_check: Time.zone.now)
        true
      else
        results.add_result(
          AuditResults::ZIP_PART_NOT_FOUND,
          endpoint_name: part.zipped_moab_version.zip_endpoint.endpoint_name,
          s3_key: part.s3_key,
          bucket_name: bucket_name
        )
        part.update(status: 'not_found', last_existence_check: Time.zone.now)
        false
      end
    end
  end
end