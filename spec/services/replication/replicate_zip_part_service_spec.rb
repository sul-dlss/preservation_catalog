# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Replication::ReplicateZipPartService do
  subject(:results) { described_class.call(zip_part:) }

  let(:zip_part) { create(:zip_part, md5:) }
  let(:druid_version_zip_part) { instance_double(Replication::DruidVersionZipPart, file_path: '/path/to/file', read_md5: md5, size: 2048) }
  let(:s3_part) { instance_double(Aws::S3::Object, bucket_name: 'test-bucket') }
  let(:md5) { '00236a2ae558018ed13b5222ef1bd977' }

  before do
    allow(zip_part).to receive_messages(s3_part: s3_part, druid_version_zip_part: druid_version_zip_part)

    allow(s3_part).to receive(:exists?).and_return(false)
    allow(s3_part).to receive(:upload_file)
    # allow(s3_part).to receive(:metadata).and_return({})
  end

  context 'when the zip part does not exist on the endpoint' do
    before do
      allow(s3_part).to receive(:exists?).and_return(false)
    end

    it 'uploads the zip part file to the endpoint' do
      expect(results.empty?).to be true
      expect(s3_part).to have_received(:upload_file).with('/path/to/file', metadata: { checksum_md5: md5, size: '2048' })
    end
  end

  context 'when the zip part already exists on the endpoint with matching md5' do
    before do
      allow(s3_part).to receive_messages(exists?: true, metadata: { 'checksum_md5' => md5 })
    end

    it 'does not re-upload the zip part file' do
      expect(results.empty?).to be true
      expect(s3_part).not_to have_received(:upload_file)
    end
  end

  context 'when the zip part already exists on the endpoint with mismatched md5' do
    before do
      allow(s3_part).to receive_messages(exists?: true, metadata: { 'checksum_md5' => 'different_md5_value' })
    end

    it 'adds to results' do
      expect(results.to_s).to match(/replicated md5 mismatch on endpoint\d\d/)
      expect(s3_part).not_to have_received(:upload_file)
    end
  end
end
