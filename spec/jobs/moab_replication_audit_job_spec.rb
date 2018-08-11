require 'rails_helper'

describe MoabReplicationAuditJob, type: :job do
  let!(:cm) { create(:complete_moab, version: 2) }
  let(:job) { described_class.new(cm) }
  let(:logger) { instance_double(Logger, warn: true, error: true) }
  let(:results) { AuditResults.new(cm.preserved_object.druid, nil, cm.moab_storage_root, "CatalogToArchive") }

  before do
    allow(AuditResults).to receive(:new).and_return(results)
    allow(Audit::CatalogToArchive).to receive(:logger).and_return(logger)

    # TODO: can change this to allow #report_results on results and then test logging and WFS reporting in
    # a specific test.
    allow(logger).to receive(:add) # most test cases only care about a subset of the logged errors
    allow(Dor::WorkflowService).to receive(:update_workflow_error_status)
  end

  describe '#perform' do
    context 'there are no zipped moab versions to backfill' do
      # zipped moab versions are automatically created for cm
      it 'does not log a warning about uncreated ZMVs' do
        expect(logger).not_to receive(:add).with(Logger::WARN, /backfilled the following ZippedMoabVersions/)
        job.perform(cm)
      end
    end

    context 'there are zipped_moab_versions to backfill for complete_moab' do
      before { cm.zipped_moab_versions.destroy_all } # undo auto-spawned rows from callback

      it 'logs a warning about uncreated ZMVs' do
        msg = "CatalogToArchive(#{cm.preserved_object.druid}, #{cm.moab_storage_root.name}) backfilled the following"\
          " ZippedMoabVersions: 1 to mock_archive1; 2 to mock_archive1"
        expect(logger).to receive(:add).with(Logger::WARN, msg)
        job.perform(cm)
      end
    end

    it 'checks all of the zipped_moab_versions that check_child_zip_part_attributes indicates are checkable' do
      expect(Audit::CatalogToArchive).to receive(:check_child_zip_part_attributes)
        .with(cm.zipped_moab_versions.first, results).and_return(true)
      expect(Audit::CatalogToArchive).to receive(:check_child_zip_part_attributes)
        .with(cm.zipped_moab_versions.second, results).and_return(false)
      expect(PreservationCatalog::S3::Audit).to receive(:check_aws_replicated_zipped_moab_version)
        .with(cm.zipped_moab_versions.first, results)
      expect(PreservationCatalog::S3::Audit).not_to receive(:check_aws_replicated_zipped_moab_version)
        .with(cm.zipped_moab_versions.second, results)
      job.perform(cm)
    end
  end
end
