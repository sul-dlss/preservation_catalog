# frozen_string_literal: true

module Replication
  # The Application's configured interface to GCP's S3 compatible service.
  class GcpProvider
    delegate :client, to: :resource
    attr_reader :aws_client_args

    def initialize(region:, access_key_id:, secret_access_key:)
      @aws_client_args = {
        region: region,
        access_key_id: access_key_id,
        secret_access_key: secret_access_key,
        endpoint: Settings.zip_endpoints.gcp_s3_central_1.endpoint_node
      }
    end

    # @return [::Aws::S3::Bucket]
    def bucket
      resource.bucket(bucket_name)
    end

    # @return [String]
    def bucket_name
      Settings.zip_endpoints.gcp_s3_central_1.storage_location
    end

    # @return [::Aws::S3::Resource]
    def resource
      ::Aws::S3::Resource.new(aws_client_args)
    end
  end
end
