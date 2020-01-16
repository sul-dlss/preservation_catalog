# frozen_string_literal: true

require 'rails_helper'

describe PreservationCatalog::Ibm do
  before do
    described_class.configure(
      region: 'us-south',
      access_key_id: 'some_key',
      secret_access_key: 'secret'
    )
  end

  describe '.resource' do
    it 'builds a client with an http/s endpoint setting' do
      expect(Aws::S3::Resource).to receive(:new).with(hash_including(endpoint: 'https://s3.us-south.cloud-object-storage.appdomain.cloud'))
      described_class.resource
    end
  end

  describe '.bucket_name' do
    context 'without ENV variable' do
      it 'returns value from Settings' do
        expect(described_class.bucket_name).to eq 'sul-sdr-ibm-us-south-1-test'
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
      expect(config.region).to eq 'us-south'
      expect(config.credentials).to be_an(Aws::Credentials)
      expect(config.credentials).to be_set
      expect(config.credentials.access_key_id).to eq 'some_key'
    end
  end
end
