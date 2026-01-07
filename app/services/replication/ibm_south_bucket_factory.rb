# frozen_string_literal: true

module Replication
  # Factory for an IBM Bucket object for the IBM US South endpoint
  class IbmSouthBucketFactory
    # @return [Aws::S3::Bucket]
    def self.bucket
      Replication::IbmProvider.new(
        region: Settings.zip_endpoints.ibm_us_south.region,
        access_key_id: Settings.zip_endpoints.ibm_us_south.access_key_id,
        secret_access_key: Settings.zip_endpoints.ibm_us_south.secret_access_key
      ).bucket
    end
  end
end
