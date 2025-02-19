# frozen_string_literal: true

module Audit
  # Base class for AWS and IBM audit classes
  class ReplicationToEndpointBase
    def self.check_replicated_zipped_moab_version(zmv, results, check_unreplicated_parts = false)
      new(zmv, results, check_unreplicated_parts).check_replicated_zipped_moab_version
    end

    delegate :bucket, :bucket_name, to: :s3_provider

    attr_reader :zmv, :results, :check_unreplicated_parts

    # @param [ZippedMoabVersion] the ZippedMoabVersion to check
    # @param [Audit::Results] the Audit::Results instance used to track findings for this audit run
    # @param [Boolean] defaults to false, skipping parts that aren't expected to be replicated.  "true" is useful for manual auditing, see wiki.
    def initialize(zmv, results, check_unreplicated_parts)
      @zmv = zmv
      @results = results
      @check_unreplicated_parts = check_unreplicated_parts
    end

    def check_replicated_zipped_moab_version
      zip_parts_to_check.each do |part|
        s3_object = bucket.object(part.s3_key)
        next unless check_existence(s3_object, part)
        next unless compare_checksum_metadata(s3_object, part)

        part.ok!
      end
    end

    def s3_provider
      @s3_provider ||= s3_provider_class.new(
        region: Settings.zip_endpoints[zmv.zip_endpoint.endpoint_name].region,
        access_key_id: Settings.zip_endpoints[zmv.zip_endpoint.endpoint_name].access_key_id,
        secret_access_key: Settings.zip_endpoints[zmv.zip_endpoint.endpoint_name].secret_access_key
      )
    end

    private

    # @return [S3::AwsProvider, S3::IbmProvider] class that will provide .bucket, and .bucket_name methods
    def s3_provider_class
      raise 'this method should be implemented by the child class'
    end

    def zip_parts_to_check
      return zmv.zip_parts.where.not(status: :unreplicated) unless check_unreplicated_parts
      zmv.zip_parts
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
          Audit::Results::ZIP_PART_CHECKSUM_MISMATCH,
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
          Audit::Results::ZIP_PART_NOT_FOUND,
          endpoint_name: part.zipped_moab_version.zip_endpoint.endpoint_name,
          s3_key: part.s3_key,
          bucket_name: bucket_name
        )
        status = part.unreplicated? ? 'unreplicated' : 'not_found' # stay in the intial unreplicated status if starting there
        part.update(status: status, last_existence_check: Time.zone.now)
        false
      end
    end
  end
end
