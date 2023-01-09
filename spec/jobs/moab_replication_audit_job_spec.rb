# frozen_string_literal: true

require 'rails_helper'

describe MoabReplicationAuditJob do
  let(:preserved_object) { create(:preserved_object, current_version: 2) }
  let(:job) { described_class.new(preserved_object) }
  let(:logger) { instance_double(Logger) }

  before do
    allow(Audit::ReplicationSupport).to receive(:logger).and_return(logger)
    allow(Settings.replication).to receive(:audit_should_backfill).and_return(true) # enable for tests
    allow(Audit::Replication).to receive(:results).and_return([])
    # creation of MoabRecord triggers archive zip creation, as archive zips are created from moabs
    create(:moab_record, preserved_object: preserved_object, version: preserved_object.current_version)
  end

  describe '#perform' do
    let(:audit_results) { instance_double(AuditResults) }

    context 'when there are no zipped moab versions to backfill' do
      before do
        allow(Audit::Replication).to receive(:results).and_return([audit_results])
        allow(AuditResultsReporter).to receive(:report_results)
      end

      it 'calls Audit::Replication and reports results' do
        expect(logger).not_to receive(:warn)
        expect { job.perform(preserved_object) }.not_to change(ZippedMoabVersion, :count)
        expect(Audit::Replication).to have_received(:results).with(preserved_object)
        expect(AuditResultsReporter).to have_received(:report_results).with(audit_results: audit_results, logger: logger)
      end
    end

    context 'when there are zipped_moab_versions to backfill' do
      before { preserved_object.zipped_moab_versions.destroy_all } # undo auto-spawned rows from callback

      it 'does nothing when backfilling is disabled' do
        allow(Settings.replication).to receive(:audit_should_backfill).and_return(false)
        expect(preserved_object).not_to receive(:create_zipped_moab_versions!)
        expect { job.perform(preserved_object) }.not_to change(ZippedMoabVersion, :count)
      end

      it 'creates missing zipped moab versions and logs a warning' do
        expect(preserved_object).to receive(:create_zipped_moab_versions!).and_call_original
        expect(logger).to receive(:warn)
          .with(/backfilled 4 ZippedMoabVersions: 1 to aws_s3_west_2; 1 to ibm_us_south; 2 to aws_s3_west_2; 2 to ibm_us_south/)
        expect(Audit::Replication).not_to receive(:results)
        job.perform(preserved_object)
      end
    end
  end
end
