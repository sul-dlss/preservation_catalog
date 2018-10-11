require 'rails_helper'

describe MoabReplicationAuditJob, type: :job do
  let(:cm) { create(:complete_moab, version: 2) }
  let(:job) { described_class.new(cm) }
  let(:logger) { instance_double(Logger) }

  before do
    allow(Audit::CatalogToArchive).to receive(:logger).and_return(logger)
    allow(Settings.replication).to receive(:audit_should_backfill).and_return(true) # enable for tests
  end

  describe '#backfill_missing_zmvs' do
    it 'when backfilling is disabled, does nothing' do
      allow(Settings.replication).to receive(:audit_should_backfill).and_return(false)
      expect(cm).not_to receive(:create_zipped_moab_versions!)
      job.send(:backfill_missing_zmvs, cm)
    end

    context 'when there are no zipped moab versions to backfill' do
      it 'does not log a warning' do
        expect(logger).not_to receive(:warn)
        job.send(:backfill_missing_zmvs, cm)
      end
    end

    context 'when there are zipped_moab_versions to backfill' do
      before { cm.zipped_moab_versions.destroy_all } # undo auto-spawned rows from callback

      it 'creates missing ZMVs and logs a warning' do
        expect(cm).to receive(:create_zipped_moab_versions!).and_call_original
        expect(logger).to receive(:warn).with(/backfilled 2 ZippedMoabVersions: 1 to mock_archive1; 2 to mock_archive1/)
        job.send(:backfill_missing_zmvs, cm)
      end
    end
  end

  describe '#perform' do
    it 'calls backfill_missing_zmvs' do
      expect(job).to receive(:backfill_missing_zmvs)
      job.perform(cm)
    end

    it 'updates last_archive_audit timestamp' do
      expect(cm).to receive(:update).with(last_archive_audit: Time)
      job.perform(cm)
    end

    it 'calls PartReplicationAuditJob once per related endpoint' do
      new_ep = create(:zip_endpoint)
      expect(PartReplicationAuditJob).to receive(:perform_later).with(cm, cm.zipped_moab_versions.first.zip_endpoint)
      expect(PartReplicationAuditJob).to receive(:perform_later).with(cm, new_ep)
      job.perform(cm)
    end
  end
end
