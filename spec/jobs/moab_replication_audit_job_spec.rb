require 'rails_helper'

describe MoabReplicationAuditJob, type: :job do
  let!(:cm) { create(:complete_moab, version: 2) }
  let(:job) { described_class.new(cm) }
  let(:logger) { instance_double(Logger, warn: true, error: true) }

  before do
    allow(Audit::CatalogToArchive).to receive(:logger).and_return(logger)
  end

  describe '#perform' do
    context 'there are no zipped moab versions to backfill' do
      # zipped moab versions are automatically created for cm
      it 'does not log a warning about uncreated ZMVs' do
        expect(logger).not_to receive(:warn).with(/backfilled unreplicated zipped_moab_versions/)
        job.perform(cm)
      end
    end

    context 'there are zipped_moab_versions to backfill for complete_moab' do
      before { cm.zipped_moab_versions.destroy_all } # undo auto-spawned rows from callback

      it 'logs a warning about uncreated ZMVs' do
        prefix = "#{cm.preserved_object.druid} #{cm.inspect}"
        msg = "#{prefix}: backfilled unreplicated zipped_moab_versions:"
        expect(logger).to receive(:warn).with(/#{Regexp.escape(msg)}/)
        job.perform(cm)
      end
    end

    it 'checks all of the zipped_moab_versions that check_child_zip_part_attributes indicates are checkable' do
      expect(Audit::CatalogToArchive).to receive(:check_child_zip_part_attributes)
        .with(cm.zipped_moab_versions.first).and_return(true)
      expect(Audit::CatalogToArchive).to receive(:check_child_zip_part_attributes)
        .with(cm.zipped_moab_versions.second).and_return(false)
      expect(PreservationCatalog::S3::Audit).to receive(:check_aws_replicated_zipped_moab_version)
        .with(cm.zipped_moab_versions.first)
      expect(PreservationCatalog::S3::Audit).not_to receive(:check_aws_replicated_zipped_moab_version)
        .with(cm.zipped_moab_versions.second)
      job.perform(cm)
    end
  end
end
