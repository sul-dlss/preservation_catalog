require 'rails_helper'

describe ReplicatedFileCheckJob, type: :job do
  let!(:zmv) { create(:zipped_moab_version) }
  let(:job) { described_class.new(zmv) }

  describe '#perform' do
    context 'check_child_zip_part_attributes return value' do
      it 'returns false, preventing check_aws_replicated_zipped_moab_version from running' do
        allow(Audit::CatalogToArchive).to receive(:check_child_zip_part_attributes).and_return(false)
        expect(PreservationCatalog::S3::Audit).not_to receive(:check_aws_replicated_zipped_moab_version)
        job.perform(zmv)
      end

      it 'returns true, allowing check_aws_replicated_zipped_moab_version to run' do
        allow(Audit::CatalogToArchive).to receive(:check_child_zip_part_attributes).and_return(true)
        expect(PreservationCatalog::S3::Audit).to receive(:check_aws_replicated_zipped_moab_version)
        job.perform(zmv)
      end
    end
  end
end
