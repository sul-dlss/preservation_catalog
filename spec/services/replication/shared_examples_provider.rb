# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'provider' do |provider_class, bucket_name, region, access_key_id, secret_access_key|
  let(:provider) do
    provider_class.new(
      region: region,
      access_key_id: 'some_key',
      secret_access_key: 'secret'
    )
  end

  describe '.bucket_name' do
    it 'returns value from Settings' do
      expect(provider.bucket_name).to eq bucket_name
    end
  end

  describe '.configure' do
    let(:config) { provider.client.config }

    it 'injects client configuration' do
      expect(config.region).to eq region
      expect(config.credentials).to be_an(Aws::Credentials)
      expect(config.credentials).to be_set
      expect(config.credentials.access_key_id).to eq 'some_key'
    end
  end

  context 'Live S3 bucket', :live_s3 do
    subject(:bucket) { provider.bucket }

    let(:provider) do
      described_class.new(
        region: region,
        access_key_id: access_key_id,
        secret_access_key: secret_access_key
      )
    end

    it { is_expected.to exist }

    describe '::Aws::S3::Object#upload_file' do
      subject(:s3_object) { bucket.object("test_key_#{test_key_id}") }

      let(:test_key_id) { ENV.fetch('CIRCLE_SHA1', '000')[0..6] }
      let(:dvz) { Replication::DruidVersionZip.new('bj102hs9687', 2) }
      let(:dvz_part) { Replication::DruidVersionZipPart.new(dvz, dvz.s3_key('.zip')) }
      let(:digest) { dvz_part.base64digest }
      let(:now) { Time.zone.now.iso8601 }
      let(:get_response) { s3_object.get }

      before do
        allow(Settings).to receive(:zip_storage).and_return(Rails.root.join('spec', 'fixtures', 'zip_storage'))
      end

      it 'accepts/returns File body and arbitrary metadata' do
        resp = nil
        expect { s3_object.upload_file(dvz_part.file_path, metadata: { our_time: now }) }.not_to raise_error
        expect { resp = s3_object.get }.not_to raise_error
        expect(resp).to be_a(Aws::S3::Types::GetObjectOutput)
        expect(resp.metadata.symbolize_keys).to eq(our_time: now)
        expect(resp.body.read).to eq("FOOOOBAR\n")
      end
    end
  end
end
