require 'rails_helper'

describe PreservationCatalog::S3 do
  describe '.bucket_name' do
    context 'without ENV variable' do
      it 'returns value from Settings' do
        expect(described_class.bucket_name).to eq 'sul-sdr-aws-us-west-2-test'
      end
    end
    context 'with ENV variable AWS_BUCKET_NAME' do
      before { ENV['AWS_BUCKET_NAME'] = 'bucket_44' }
      it 'returns the ENV value' do
        expect(described_class.bucket_name).to eq 'bucket_44'
      end
    end
  end

  describe 'config' do
    let(:config) { described_class.client.config }

    before do
      ENV['AWS_SECRET_ACCESS_KEY'] = 'secret'
      ENV['AWS_ACCESS_KEY_ID'] = 'some_key'
      ENV['AWS_REGION'] = 'us-east-1'
    end
    it 'pulls from ENV vars' do
      expect(config.region).to eq 'us-east-1'
      expect(config.credentials).to be_an(Aws::Credentials)
      expect(config.credentials).to be_set
      expect(config.credentials.access_key_id).to eq 'some_key'
    end
  end
end
