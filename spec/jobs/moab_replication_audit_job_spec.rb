# frozen_string_literal: true

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
        expect(logger).to receive(:warn).with(/backfilled 4 ZippedMoabVersions: 1 to aws_s3_west_2; 1 to ibm_us_south; 2 to aws_s3_west_2; 2 to ibm_us_south/)
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
      new_endpoint = create(:zip_endpoint) # before `cm` invoked, means default policy will include it when making cm
      # make sure our new_endpoint is included, even though the association isn't the audit's responsibility
      expect(cm.zipped_moab_versions.pluck(:zip_endpoint_id)).to include(new_endpoint.id)
      ZipEndpoint.includes(:zipped_moab_versions).where(zipped_moab_versions: { complete_moab: cm }).each do |endpoint|
        expect(PartReplicationAuditJob).to receive(:perform_later).with(cm, endpoint)
      end
      job.perform(cm)
    end
  end
end
