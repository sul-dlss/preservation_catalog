# frozen_string_literal: true

require 'rails_helper'
require 'services/replication/shared_examples_provider'

describe Replication::GcpProvider do
  it_behaves_like 'provider', described_class,
                  Settings.zip_endpoints.gcp_s3_south_1.storage_location,
                  Settings.zip_endpoints.gcp_s3_south_1.region,
                  Settings.zip_endpoints.gcp_s3_south_1.access_key_id,
                  Settings.zip_endpoints.gcp_s3_south_1.secret_access_key

  describe '.resource' do
    let(:provider) do
      described_class.new(
        region: Settings.zip_endpoints.gcp_s3_south_1.region,
        access_key_id: 'some_key',
        secret_access_key: 'secret'
      )
    end

    it 'builds a client with an http/s endpoint setting' do
      expect(Aws::S3::Resource).to receive(:new).with(hash_including(endpoint: Settings.zip_endpoints.gcp_s3_south_1.endpoint_node))
      provider.resource
    end
  end
end
