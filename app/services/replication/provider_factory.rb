# frozen_string_literal: true

module Replication
  # Factory for replication provider instances based on ZipEndpoint configuration.
  class ProviderFactory
    def self.create(...)
      new(...).create
    end

    # @param zip_endpoint [ZipEndpoint] the ZipEndpoint to use for configuration
    # @param access_key_id [String, nil] optional access key override
    # @param secret_access_key [String, nil] optional secret access key override
    def initialize(zip_endpoint:, access_key_id: nil, secret_access_key: nil)
      @zip_endpoint = zip_endpoint
      @access_key_id = access_key_id
      @secret_access_key = secret_access_key
    end

    # @return [Replication::AwsProvider, Replication::IbmProvider, Replication::GcpProvider]
    def create
      raise 'Unknown endpoint configuration' unless endpoint_settings&.provider_class

      provider_class.new(
        zip_endpoint:,
        access_key_id: access_key_id || endpoint_settings.access_key_id,
        secret_access_key: secret_access_key || endpoint_settings.secret_access_key
      )
    end

    private

    attr_reader :zip_endpoint, :access_key_id, :secret_access_key

    def endpoint_settings
      @endpoint_settings ||= Settings.zip_endpoints[zip_endpoint.endpoint_name]
    end

    def provider_class
      endpoint_settings.provider_class.constantize
    end
  end
end
