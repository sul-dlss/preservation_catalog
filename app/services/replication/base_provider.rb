# frozen_string_literal: true

module Replication
  # The Application's configured general interface to AWS S3 compatible resources.
  class BaseProvider
    delegate :client, to: :resource
    attr_reader :aws_client_args

    def initialize(zip_endpoint:, access_key_id:, secret_access_key:)
      @zip_endpoint = zip_endpoint
      @aws_client_args = {
        region: endpoint_settings.region,
        access_key_id: access_key_id,
        secret_access_key: secret_access_key
      }
    end

    # @return [::Aws::S3::Bucket]
    def bucket
      resource.bucket(bucket_name)
    end

    # @return [String]
    def bucket_name
      endpoint_settings.storage_location
    end

    # @return [::Aws::S3::Resource]
    def resource
      ::Aws::S3::Resource.new(aws_client_args)
    end

    def endpoint_settings
      @endpoint_settings ||= Settings.zip_endpoints[@zip_endpoint.endpoint_name]
    end
  end
end
