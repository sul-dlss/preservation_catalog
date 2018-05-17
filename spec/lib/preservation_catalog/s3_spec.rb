require 'rails_helper'

describe PreservationCatalog::S3 do
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

  describe 'config' do
    let(:config) { described_class.client.config }
    let(:trio) do
      {
        'AWS_SECRET_ACCESS_KEY' => 'secret',
        'AWS_ACCESS_KEY_ID' => 'some_key',
        'AWS_REGION' => 'us-east-1'
      }
    end

    around do |example|
      old_vals = trio.keys.zip(ENV.values_at(*trio.keys)).to_h
      trio.each { |k, v| ENV[k] = v }
      example.run
      old_vals.each { |k, v| ENV[k] = v }
    end
    it 'pulls from ENV vars' do
      expect(config.region).to eq 'us-east-1'
      expect(config.credentials).to be_an(Aws::Credentials)
      expect(config.credentials).to be_set
      expect(config.credentials.access_key_id).to eq 'some_key'
    end
  end

  context 'Live S3 bucket', live_s3: true do
    subject(:bucket) { described_class.bucket }

    it { is_expected.to exist }

    describe 'Aws::S3::Object#put' do
      subject(:s3_object) { bucket.object('test_key') }

      let(:dvz) { DruidVersionZip.new('bj102hs9687', 2) }
      let(:file) { File.open(dvz.file) }
      let(:now) { Time.zone.now.iso8601 }
      let(:get_response) { s3_object.get }

      before do
        allow(Settings).to receive(:zip_storage).and_return(Rails.root.join('spec', 'fixtures', 'zip_storage'))
      end

      it 'accepts/returns File body and arbitrary metadata' do
        resp = nil
        expect { s3_object.put(body: file, metadata: { our_time: now }) }.not_to raise_error
        expect { resp = s3_object.get }.not_to raise_error
        expect(resp).to be_a(Aws::S3::Types::GetObjectOutput)
        expect(resp.metadata.symbolize_keys).to eq(our_time: now)
        expect(resp.body.read).to eq("FOOOOBAR\n")
      end

      context 'when content_md5 matches body' do
        it 'accepts upload' do
          expect { s3_object.put(body: file, content_md5: dvz.md5) }.not_to raise_error
        end
      end

      context 'when content_md5 does not match body' do
        it 'rejects upload' do
          expect { s3_object.put(body: 'ZUBAZ', content_md5: dvz.md5) }.to raise_error Aws::S3::Errors::BadDigest
        end
      end

      context 'when content_md5 is invalid' do
        it 'rejects upload' do
          expect { s3_object.put(body: file, content_md5: "X#{dvz.md5}") }.to raise_error Aws::S3::Errors::InvalidDigest
        end
      end
    end
  end
end
