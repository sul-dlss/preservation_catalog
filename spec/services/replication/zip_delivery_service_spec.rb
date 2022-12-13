# frozen_string_literal: true

require 'rails_helper'

describe Replication::ZipDeliveryService do
  let(:instance) { described_class.new(s3_part: s3_part, dvz_part: dvz_part, metadata: metadata) }
  let(:druid) { 'bj102hs9687' }
  let(:version) { 1 }
  let(:dvz) { Replication::DruidVersionZip.new(druid, version) }
  let(:dvz_part) { Replication::DruidVersionZipPart.new(dvz, part_s3_key) }
  let(:bucket_name) { 's3-bucket-shop' }
  let(:s3_part) { instance_double(Aws::S3::Object, exists?: part_exists, upload_file: true, key: part_s3_key, bucket_name: bucket_name) }
  let(:part_exists) { false }
  let(:md5) { '4f98f59e877ecb84ff75ef0fab45bac5' }
  let(:base64) { dvz.hex_to_base64(md5) }
  let(:metadata) { dvz_part.metadata.merge(zip_version: 'Zip 3.0 (July 5th 2008)') }
  let(:part_s3_key) { dvz.s3_key('.zip') }

  before do
    allow(Settings).to receive(:zip_storage).and_return(Rails.root.join('spec', 'fixtures', 'zip_storage'))
    allow(IO).to receive(:read).with(dvz_part.md5_path).and_return(md5)
  end

  describe '.deliver' do
    before do
      allow(described_class).to receive(:new).and_return(instance)
      allow(instance).to receive(:deliver)
    end

    it 'invokes #deliver on a new instance' do
      described_class.deliver(s3_part: s3_part, dvz_part: dvz_part, metadata: metadata)
      expect(instance).to have_received(:deliver).once
    end
  end

  describe '#deliver' do
    before do
      allow(Honeybadger).to receive(:notify)
    end

    context 'when s3 part exists' do
      let(:part_exists) { true }

      it 'returns nil, does not upload the file, and notifies Honeybadger' do
        expect(instance.deliver).to be_nil
        expect(s3_part).not_to have_received(:upload_file)
        expect(Honeybadger).to have_received(:notify).with(
          a_string_matching(/^WARNING: S3 location already has content./),
          context: a_hash_including(druid: "druid:#{druid}", version: version, endpoint: bucket_name)
        )
      end
    end

    context 'when s3 part does not exist' do
      context 'when checksums do not match' do
        let(:md5) { nil }

        it 'raises a RuntimeError' do
          expect { instance.deliver }.to raise_error(/bj102hs9687.v0001.zip MD5 mismatch/)
          expect(s3_part).not_to have_received(:upload_file)
        end
      end

      it 'delivers the zip' do
        instance.deliver
        expect(s3_part).to have_received(:upload_file).with(
          dvz_part.file_path, metadata: a_hash_including(checksum_md5: md5)
        )
      end
    end
  end
end
