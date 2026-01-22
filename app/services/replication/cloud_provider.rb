# frozen_string_literal: true

module Replication
  # The Application's configured general interface to cloud based, AWS S3 compatible resources.
  class CloudProvider
    delegate :client, to: :resource
    attr_reader :client_args, :endpoint_settings

    def initialize(endpoint_settings:, access_key_id:, secret_access_key:)
      @endpoint_settings = endpoint_settings
      @client_args = {
        region: endpoint_settings.region,
        access_key_id: access_key_id,
        secret_access_key: secret_access_key,
        endpoint:
      }.compact
    end

    # @return [::Aws::S3::Bucket]
    def bucket
      resource.bucket(bucket_name)
    end

    # @return [String]
    def bucket_name
      endpoint_settings.storage_location
    end

    # @return [String, nil]
    # Endpoint can only be set if it is a valid URL.
    def endpoint
      return unless endpoint_settings.endpoint_node =~ %r{^https?://}i

      endpoint_settings.endpoint_node
    end

    # @return [::Aws::S3::Resource]
    def resource
      ::Aws::S3::Resource.new(client_args)
    end
  end
end
