# frozen_string_literal: true

require 'rails_helper'

describe PreservationCatalog::S3 do
  before do
    described_class.configure(
      region: 'us-west-2',
      access_key_id: 'some_key',
      secret_access_key: 'secret'
    )
  end

  describe '.bucket_name' do
    context 'without ENV variable' do
      it 'returns value from Settings' do
        expect(described_class.bucket_name).to eq 'sul-sdr-aws-us-west-2-test'
      end
    end

    context 'with ENV variable AWS_BUCKET_NAME' do
      around do |example|
        old_val = ENV['AWS_BUCKET_NAME']
        ENV['AWS_BUCKET_NAME'] = 'bucket_44'
        example.run
        ENV['AWS_BUCKET_NAME'] = old_val
      end

      it 'returns the ENV value' do
        expect(described_class.bucket_name).to eq 'bucket_44'
      end
    end
  end

  describe '.configure' do
    let(:config) { described_class.client.config }

    it 'injects client configuration' do
      expect(config.region).to eq 'us-west-2'
      expect(config.credentials).to be_an(Aws::Credentials)
      expect(config.credentials).to be_set
      expect(config.credentials.access_key_id).to eq 'some_key'
    end
  end
end
