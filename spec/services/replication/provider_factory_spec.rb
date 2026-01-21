# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Replication::ProviderFactory do
  subject(:provider) { described_class.create(zip_endpoint:) }

  context 'when the endpoint configuration exists' do
    let(:zip_endpoint) { instance_double(ZipEndpoint, endpoint_name: 'aws_s3_west_2') }

    it 'creates an AwsProvider instance' do
      expect(provider).to be_an_instance_of(Replication::AwsProvider)
      expect(provider.bucket_name).to eq('sul-sdr-aws-us-west-2-test')
    end
  end

  context 'when access keys are overridden' do
    subject(:provider) do
      described_class.create(zip_endpoint:, access_key_id:, secret_access_key:)
    end

    let(:zip_endpoint) { instance_double(ZipEndpoint, endpoint_name: 'aws_s3_west_2') }
    let(:access_key_id) { 'OVERRIDDEN_ACCESS_KEY_ID' }
    let(:secret_access_key) { 'OVERRIDDEN_SECRET_ACCESS_KEY' }

    it 'creates the provider with the overridden keys' do
      expect(provider).to be_an_instance_of(Replication::AwsProvider)
      expect(provider.client.config.credentials.access_key_id).to eq(access_key_id)
      expect(provider.client.config.credentials.secret_access_key).to eq(secret_access_key)
    end
  end

  context 'when the endpoint configuration is missing' do
    let(:zip_endpoint) { instance_double(ZipEndpoint, endpoint_name: 'non_existent_endpoint') }

    it 'raises an error' do
      expect { provider }.to raise_error('Unknown endpoint configuration')
    end
  end
end
