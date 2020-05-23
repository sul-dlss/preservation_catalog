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
      expect(config.credentials).to be_an(::Aws::Credentials)
      expect(config.credentials).to be_set
      expect(config.credentials.access_key_id).to eq 'some_key'
    end
  end

  context 'Live S3 bucket', live_aws: true do
    subject(:bucket) { described_class.bucket }

    before do
      described_class.configure(
        region: Settings.zip_endpoints.aws_s3_west_2.region,
        access_key_id: Settings.zip_endpoints.aws_s3_west_2.access_key_id,
        secret_access_key: Settings.zip_endpoints.aws_s3_west_2.secret_access_key
      )
    end

    it { is_expected.to exist }

    describe '::Aws::S3::Object#upload_file' do
      subject(:s3_object) { bucket.object("test_key_#{test_key_id}") }

      let(:test_key_id) { ENV.fetch('TRAVIS_JOB_ID', '000') }
      let(:dvz) { DruidVersionZip.new('bj102hs9687', 2) }
      let(:dvz_part) { DruidVersionZipPart.new(dvz, dvz.s3_key('.zip')) }
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
        expect(resp).to be_a(::Aws::S3::Types::GetObjectOutput)
        expect(resp.metadata.symbolize_keys).to eq(our_time: now)
        expect(resp.body.read).to eq("FOOOOBAR\n")
      end
    end
  end
end
