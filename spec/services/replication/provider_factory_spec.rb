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

  context 'when the endpoint configuration is missing' do
    let(:zip_endpoint) { instance_double(ZipEndpoint, endpoint_name: 'non_existent_endpoint') }

    it 'raises an error' do
      expect { provider }.to raise_error('Unknown endpoint configuration')
    end
  end
end
