require 'rails_helper'

describe PreservationCatalog::Ibm do
  describe '.resource' do
    it 'builds a client with an http/s endpoint setting' do
      # zip_endpoints_setting = Config::Options.new(
      #   ibm_us_south:
      #     Config::Options.new(
      #       endpoint_node: 'https://ibm.endpoint.biz',
      #       storage_location: 'storage_location',
      #       delivery_class: 'IbmSouthDeliveryJob'
      #     )
      # )
      # allow(Settings).to receive(:zip_endpoints).and_return(zip_endpoints_setting)
      expect(Aws::S3::Resource).to receive(:new).with(hash_including(endpoint: 'https://ibm.endpoint.biz'))
      described_class.resource
    end
  end
  describe '.bucket_name' do
    context 'without ENV variable' do
      it 'returns value from Settings' do
        expect(described_class.bucket_name).to eq 'sul-sdr-ibm-us-south-1-ia'
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

  describe 'config' do
    context 'with access key and region env vars' do
      let(:config) { described_class.client.config }
      let(:envs) do
        {
          'AWS_SECRET_ACCESS_KEY' => 'secret',
          'AWS_ACCESS_KEY_ID' => 'some_key',
          'AWS_REGION' => 'us-south'
        }
      end

      around do |example|
        old_vals = envs.keys.zip(ENV.values_at(*envs.keys)).to_h
        envs.each { |k, v| ENV[k] = v }
        example.run
        old_vals.each { |k, v| ENV[k] = v }
      end

      it 'pulls from ENV vars' do
        expect(config.region).to eq 'us-south'
        expect(config.credentials).to be_an(Aws::Credentials)
        expect(config.credentials).to be_set
        expect(config.credentials.access_key_id).to eq 'some_key'
      end
    end
  end

end
