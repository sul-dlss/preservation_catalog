require 'rails_helper'

describe ReplicatedFileCheckJob, type: :job do
  let!(:zmv) { create(:zipped_moab_version) }
  let(:job) { described_class.new(zmv) }

  describe '#perform' do
    it 'calls C2A on the given ZMV' do
      expect(PreservationCatalog::S3::Audit).to receive(:check_aws_replicated_zipped_moab_version).with(zmv)
      job.perform(zmv)
    end
  end
end
