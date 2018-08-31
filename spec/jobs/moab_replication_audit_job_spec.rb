require 'rails_helper'

describe MoabReplicationAuditJob, type: :job do
  let!(:cm) { create(:complete_moab, version: 2) }
  let(:job) { described_class.new(cm) }
  let(:results) { AuditResults.new(cm.preserved_object.druid, nil, cm.moab_storage_root, "MoabReplicationAuditJob") }

  before do
    allow(AuditResults).to receive(:new).and_return(results)
    allow(results).to receive(:report_results)
    allow(Settings.replication).to receive(:audit_should_backfill).and_return(true) # default to enabled for tests
  end

  describe '#perform' do
    context 'there are no zipped moab versions to backfill' do
      # zipped moab versions are automatically created for cm
      it 'does not log a warning about uncreated ZMVs' do
        job.perform(cm)
        expect(results.result_array).not_to include(a_hash_including(AuditResults::ZMV_BACKFILL))
      end
    end

    context 'there are zipped_moab_versions to backfill for complete_moab' do
      before { cm.zipped_moab_versions.destroy_all } # undo auto-spawned rows from callback

      it 'tries to create missing ZMVs and logs a warning about uncreated ZMVs' do
        expect(cm).to receive(:create_zipped_moab_versions!).and_call_original
        job.perform(cm)
        msg = "backfilled the following ZippedMoabVersions: 1 to mock_archive1; 2 to mock_archive1"
        expect(results.result_array).to include(a_hash_including(AuditResults::ZMV_BACKFILL => msg))
      end

      context 'automatic backfilling is disabled' do
        before { allow(Settings.replication).to receive(:audit_should_backfill).and_return(false) }

        it 'does not try to create ZippedMoabVersions for the CompleteMoab' do
          expect(cm).not_to receive(:create_zipped_moab_versions!)
          job.perform(cm)
          expect(results.result_array).not_to include(a_hash_including(AuditResults::ZMV_BACKFILL))
        end
      end
    end

    it "calls report_results with the right logger" do
      skip "Temporarily turning off reporting to WF because long messages aren't accepted"
      expect(results).to receive(:report_results).with(Audit::CatalogToArchive.logger)
      job.perform(cm)
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
