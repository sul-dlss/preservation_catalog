require 'rails_helper'

describe ReplicationCheckJob, type: :job do
  let(:version) { 1 }
  let(:zip_checksum) { create(:zip_checksum, preserved_copy: pc) }
  let(:po) { create(:preserved_object, druid: 'bj102hs9687', current_version: version) }
  let!(:pc) { create(:archive_copy, preserved_object: po, version: version) }
  let(:s3_object) { instance_double(Aws::S3::Object, exists?: false, put: true) }
  let(:bucket) { instance_double(Aws::S3::Bucket, object: s3_object) }
  let(:bucket_name) { "sul-sdr-us-west-bucket" }
  let(:file) { "bj/102/hs/9687/bj102hs9687.v0001.zip" }
  let(:job) { described_class.new(pc) }
  let(:replicated_checksum) { "00236a2ae558018ed13b5222ef1bd977" }
  let(:stored_checksums) { ["asdfasdfb43t347l;x5px54xx6549;f4"] }

  before do
    allow(PreservationCatalog::S3).to receive(:bucket).and_return(bucket)
    allow(PreservationCatalog::S3).to receive(:bucket_name).and_return(bucket_name)
    allow(job).to receive(:stored_checksums).and_return(stored_checksums)
    allow(job).to receive(:replicated_checksum).and_return(replicated_checksum)
  end

  context 'zip exists on s3' do
    let(:timestamp) { Time.zone.now }

    before do
      allow(Time).to receive(:now).and_return(timestamp)
      allow(s3_object).to receive(:exists?).and_return(true)
    end

    context 'stored db checksum matches replicated s3 object checksum' do
      it 'updates the status and last_checksum_validation timestamp' do
        allow(stored_checksums).to receive(:include?).with(replicated_checksum).and_return(true)
        expect(pc).to receive(:update).with(last_checksum_validation: timestamp)
        expect(pc).to receive(:ok!)
        job.perform(pc)
      end
    end

    context 'stored db checksum does not match replicated aws object checksum' do

      it "updates preserved copy status" do
        expect(stored_checksums).to receive(:include?).with(replicated_checksum).and_return(false)
        expect(pc).to receive(:update).with(last_checksum_validation: timestamp)
        expect(pc).to receive(:invalid_checksum!)
        job.perform(pc)
      end
    end
  end

  context 'zip does not exist on s3' do
    before { allow(s3_object).to receive(:exists?).and_return(false) }

    it 'updates preserved copy status' do
      expect(pc).to receive(:replicated_copy_not_found!)
      job.perform(pc)
    end
  end

  context "preserved copy has status 'unreplicated'" do
    let!(:pc) { create(:archive_copy, preserved_object: po, version: version, status: 'unreplicated') }

    it "#perform returns on pres_copies" do
      expect(job.perform(pc)).to be_nil
      expect(pc).not_to receive(:save!)

    end
  end

  describe '#stored_checksums' do
    it 'returns the correct array of checksums' do
      expect(job.stored_checksums(pc)).to eq stored_checksums
    end
  end

  describe '#replicated_checksum' do
    it 'returns the correct checksum string' do
      expect(job.replicated_checksum(s3_object)).to eq replicated_checksum
    end
  end
end
