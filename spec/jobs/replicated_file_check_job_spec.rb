require 'rails_helper'

describe ReplicatedFileCheckJob, type: :job do
  let(:version) { 1 }
  let(:po) { create(:preserved_object, druid: 'bj102hs9687', current_version: version) }
  let!(:cm) { create(:archive_copy_deprecated, preserved_object: po, version: version) }
  let(:s3_object) { instance_double(Aws::S3::Object, exists?: false, put: true) }
  let(:bucket) { instance_double(Aws::S3::Bucket, object: s3_object) }
  let(:bucket_name) { "sul-sdr-us-west-bucket" }
  let(:file) { "bj/102/hs/9687/bj102hs9687.v0001.zip" }
  let(:job) { described_class.new(cm) }
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
        expect(cm).to receive(:ok!)
        job.perform(cm)
        expect(cm.last_checksum_validation).to eq timestamp
      end
    end

    context 'stored db checksum does not match replicated aws object checksum' do

      it "updates preserved copy status" do
        expect(stored_checksums).to receive(:include?).with(replicated_checksum).and_return(false)
        expect(Rails.logger).to receive(:error).with(
          "Stored checksum(#{stored_checksums}) doesn't include the replicated checksum(#{replicated_checksum})."
        )
        expect(cm).to receive(:invalid_checksum!)
        job.perform(cm)
        expect(cm.last_checksum_validation).to eq timestamp
      end
    end
  end

  context 'zip does not exist on s3' do
    before { allow(s3_object).to receive(:exists?).and_return(false) }

    it 'updates preserved copy status' do
      expect(Rails.logger).to receive(:error).with("Archival Complete Moab: #{cm} was not found on #{bucket_name}.")

      expect(cm).to receive(:replicated_copy_not_found!)
      job.perform(cm)
    end
  end

  context "preserved copy has status 'unreplicated'" do
    let!(:cm) { create(:archive_copy_deprecated, preserved_object: po, version: version, status: 'unreplicated') }

    it "#perform returns on pres_copies" do
      expect(Rails.logger).to receive(:error).with("#{cm} should be replicated, but has a status of #{cm.status}.")
      expect(job.perform(cm)).to be_nil
      expect(cm).not_to receive(:save!)
    end
  end

  describe '#stored_checksums' do
    it 'returns the correct array of checksums' do
      expect(job.stored_checksums(cm)).to eq stored_checksums
    end
  end

  describe '#replicated_checksum' do
    it 'returns the correct checksum string' do
      expect(job.replicated_checksum(s3_object)).to eq replicated_checksum
    end
  end
end
