# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Replication::ReplicateZipPartService do
  subject(:results) { described_class.call(zip_part:) }

  let(:zip_part) { create(:zip_part, md5:) }
  let(:zip_part_file) { instance_double(Replication::ZipPartFile, file_path: '/path/to/file', read_md5: md5, size: 2048) }
  let(:s3_part) { instance_double(Aws::S3::Object, bucket_name: 'test-bucket') }
  let(:md5) { '00236a2ae558018ed13b5222ef1bd977' }
  let(:transfer_manager) { instance_double(Aws::S3::TransferManager) }
  let(:bucket_name) { 'sul-sdr-aws-us-west-2-test' }
  let(:provider) { instance_double(Replication::CloudProvider, client:, bucket_name:) }
  let(:client) { instance_double(Aws::S3::Client) }

  before do
    allow(zip_part).to receive_messages(s3_part:, zip_part_file:)

    allow(s3_part).to receive(:exists?).and_return(false)
    allow(Aws::S3::TransferManager).to receive(:new).with(client:).and_return(transfer_manager)
    allow(transfer_manager).to receive(:upload_file)
    allow(Replication::ProviderFactory).to receive(:create).and_return(provider)
  end

  context 'when the zip part does not exist on the endpoint' do
    it 'uploads the zip part file to the endpoint' do
      expect(results.empty?).to be true
      expect(transfer_manager).to have_received(:upload_file)
        .with('/path/to/file',
              bucket: bucket_name,
              key: zip_part.s3_key,
              metadata: { checksum_md5: md5, size: '2048' })
    end
  end

  context 'when the zip part already exists on the endpoint with matching md5' do
    before do
      allow(s3_part).to receive_messages(exists?: true, metadata: { 'checksum_md5' => md5 })
    end

    it 'does not re-upload the zip part file' do
      expect(results.empty?).to be true
      expect(transfer_manager).not_to have_received(:upload_file)
    end
  end

  context 'when the zip part already exists on the endpoint with mismatched md5' do
    before do
      allow(s3_part).to receive_messages(exists?: true, metadata: { 'checksum_md5' => 'different_md5_value' })
    end

    it 'adds to results' do
      expect(results.to_s).to match(/replicated md5 mismatch on endpoint\d\d/)
      expect(transfer_manager).not_to have_received(:upload_file)
    end
  end
end
