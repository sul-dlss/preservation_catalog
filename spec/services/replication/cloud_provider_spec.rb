# frozen_string_literal: true

require 'rails_helper'
require 'services/replication/shared_examples_provider'

describe Replication::CloudProvider do
  context 'with an AWS S3 endpoint' do
    it_behaves_like 'provider',
                    Settings.zip_endpoints.aws_s3_west_2.storage_location,
                    Settings.zip_endpoints.aws_s3_west_2.region,
                    Settings.zip_endpoints.aws_s3_west_2.access_key_id,
                    Settings.zip_endpoints.aws_s3_west_2.secret_access_key

    describe '.resource' do
      let(:provider) do
        described_class.new(
          endpoint_settings: Settings.zip_endpoints.aws_s3_west_2,
          access_key_id: 'some_key',
          secret_access_key: 'secret'
        )
      end

      it 'builds a client without an endpoint setting' do
        expect(Aws::S3::Resource).to receive(:new).with(satisfy { |h| !h.key?(:endpoint) })
        provider.resource
      end
    end
  end

  context 'with a GCP S3 compatible endpoint' do
    it_behaves_like 'provider',
                    Settings.zip_endpoints.gcp_s3_south_1.storage_location,
                    Settings.zip_endpoints.gcp_s3_south_1.region,
                    Settings.zip_endpoints.gcp_s3_south_1.access_key_id,
                    Settings.zip_endpoints.gcp_s3_south_1.secret_access_key

    describe '.resource' do
      let(:provider) do
        described_class.new(
          endpoint_settings: Settings.zip_endpoints.gcp_s3_south_1,
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
end
