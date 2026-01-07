# frozen_string_literal: true

module Replication
  # Factory for replication provider instances based on ZipEndpoint configuration.
  class ProviderFactory
    def self.create(...)
      new(...).create
    end

    def initialize(zip_endpoint:)
      @zip_endpoint = zip_endpoint
    end

    # @return [Replication::AwsProvider, Replication::IbmProvider, Replication::GcpProvider]
    def create
      raise 'Unknown endpoint configuration' unless endpoint_settings&.provider_class

      provider_class.new(
        region: endpoint_settings.region,
        access_key_id: endpoint_settings.access_key_id,
        secret_access_key: endpoint_settings.secret_access_key
      )
    end

    private

    attr_reader :zip_endpoint

    def endpoint_settings
      @endpoint_settings ||= Settings.zip_endpoints[zip_endpoint.endpoint_name]
    end

    def provider_class
      endpoint_settings.provider_class.constantize
    end
  end
end
