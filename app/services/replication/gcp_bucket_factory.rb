# frozen_string_literal: true

module Replication
  # Factory for a GCP Bucket object for the GCP US South endpoint.
  class GcpBucketFactory
    # @return [Aws::S3::Bucket]
    def self.bucket
      Replication::GcpProvider.new(
        region: Settings.zip_endpoints.gcp_s3_south_1.region,
        access_key_id: Settings.zip_endpoints.gcp_s3_south_1.access_key_id,
        secret_access_key: Settings.zip_endpoints.gcp_s3_south_1.secret_access_key
      ).bucket
    end
  end
end
