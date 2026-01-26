# frozen_string_literal: true

require 'rails_helper'

describe Replication::CloudProvider do
  subject(:provider) do
    described_class.new(endpoint_settings:, access_key_id:, secret_access_key: 'secret')
  end

  let(:access_key_id) { 'some_key' }
  # Use AWS S3 endpoint as the default case in this class's tests
  let(:endpoint_settings) { Settings.zip_endpoints.aws_s3_west_2 }

  before { allow(Aws::S3::Resource).to receive(:new).and_call_original }

  describe '#resource' do
    it 'builds a client without an endpoint setting' do
      provider.resource
      expect(Aws::S3::Resource).to have_received(:new).with(satisfy { |h| !h.key?(:endpoint) }).once
    end
  end

  describe '#bucket_name' do
    it 'returns value from Settings' do
      expect(provider.bucket_name).to eq(endpoint_settings.storage_location)
    end
  end

  describe '#configure' do
    it 'injects client configuration' do
      expect(provider.client.config.region).to eq(endpoint_settings.region)
      expect(provider.client.config.credentials).to be_an(Aws::Credentials)
      expect(provider.client.config.credentials).to be_set
      expect(provider.client.config.credentials.access_key_id).to eq(access_key_id)
    end
  end

  context 'with a GCP S3 compatible endpoint' do
    let(:endpoint_settings) { Settings.zip_endpoints.gcp_s3_south_1 }

    describe '#resource' do
      it 'builds a client with an http/s endpoint setting' do
        provider.resource
        expect(Aws::S3::Resource).to have_received(:new).with(hash_including(endpoint: endpoint_settings.endpoint_node)).once
      end
    end

    describe '#bucket_name' do
      it 'returns value from Settings' do
        expect(provider.bucket_name).to eq(endpoint_settings.storage_location)
      end
    end

    describe '#configure' do
      it 'injects client configuration' do
        expect(provider.client.config.region).to eq(endpoint_settings.region)
        expect(provider.client.config.credentials).to be_an(Aws::Credentials)
        expect(provider.client.config.credentials).to be_set
        expect(provider.client.config.credentials.access_key_id).to eq(access_key_id)
      end
    end
  end

  context 'with a live S3 bucket', :live_s3 do
    subject(:bucket) { provider.bucket }

    it { is_expected.to exist }

    describe '::Aws::S3::Object#upload_file' do
      let(:dvz) { Replication::DruidVersionZip.new('bj102hs9687', 2) }
      let(:dvz_part) { Replication::DruidVersionZipPart.new(dvz, dvz.s3_key('.zip')) }
      let(:now) { Time.zone.now.iso8601 }
      let(:transfer_manager) { Aws::S3::TransferManager.new(client: provider.client) }
      let(:zip_part) { create(:zip_part) }

      before do
        allow(Settings).to receive(:zip_storage).and_return(Rails.root.join('spec', 'fixtures', 'zip_storage'))
      end

      it 'accepts/returns File body and arbitrary metadata' do
        resp = nil
        expect do
          resp = transfer_manager.upload_file(dvz_part.file_path,
                                              bucket: provider.bucket_name,
                                              key: zip_part.s3_key,
                                              metadata: { our_time: now })
        end.not_to raise_error
        expect(resp).to be_a(Aws::S3::Types::GetObjectOutput)
        expect(resp.metadata.symbolize_keys).to eq(our_time: now)
        expect(resp.body.read).to eq("FOOOOBAR\n")
      end
    end
  end
end
