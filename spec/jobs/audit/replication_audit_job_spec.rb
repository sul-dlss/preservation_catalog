# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Audit::ReplicationAuditJob do
  let(:results) { instance_double(Results) }

  before do
    allow(Replication::AuditService).to receive(:call).and_return(results_list)
    allow(ReplicationJob).to receive(:perform_later)
    allow(ResultsReporter).to receive(:report_results)
  end

  context 'when no failures and no created/incomplete ZippedMoabVersions' do
    let(:preserved_object) { create(:preserved_object, current_version: 1) }
    let(:results_list) { [] }

    before do
      ZipEndpoint.find_each do |zip_endpoint|
        create(:zipped_moab_version, status: :ok, preserved_object:, zip_endpoint:, version: 1)
      end
    end

    it 'performs audit and does not notify or start replication' do
      expect { described_class.perform_now(preserved_object) }.to(change { preserved_object.reload.last_archive_audit })

      expect(preserved_object.reload.zipped_moab_versions.count).to eq ZipEndpoint.count
      expect(Replication::AuditService).to have_received(:call).with(preserved_object: preserved_object)
      expect(ResultsReporter).not_to have_received(:report_results)
      expect(ReplicationJob).not_to have_received(:perform_later)
    end
  end

  context 'when not all ZippedMoabVersions exists' do
    let(:preserved_object) { create(:preserved_object, current_version: 2) }
    let(:results_list) { [results] }

    before do
      ZipEndpoint.find_each do |zip_endpoint|
        create(:zipped_moab_version, status: :ok, preserved_object:, zip_endpoint:, version: 1)
      end
    end

    it 'creates the ZippedMoabVersions, performs audit and starts replication' do
      described_class.perform_now(preserved_object)

      expect(preserved_object.reload.zipped_moab_versions.count).to eq ZipEndpoint.count * 2
      expect(Replication::AuditService).to have_received(:call).with(preserved_object: preserved_object)
      expect(ReplicationJob).to have_received(:perform_later).with(preserved_object)
      expect(ResultsReporter).to have_received(:report_results).with(results:, logger: anything)
    end
  end

  context 'when some ZippedMoabVersions have failed' do
    let(:preserved_object) { create(:preserved_object, current_version: 1) }
    let(:results_list) { [results] }

    before do
      ZipEndpoint.find_each do |zip_endpoint|
        create(:zipped_moab_version, status: :failed, preserved_object:, zip_endpoint:, version: 1)
      end
    end

    it 'performs audit and notifies Honeybadger' do
      described_class.perform_now(preserved_object)

      expect(Replication::AuditService).to have_received(:call).with(preserved_object: preserved_object)
      expect(ReplicationJob).not_to have_received(:perform_later)
      expect(ResultsReporter).to have_received(:report_results).with(results:, logger: anything)
    end
  end
end
