# frozen_string_literal: true

require 'rails_helper'

describe Audit::Replication do
  let(:results) { described_class.results(preserved_object) }

  let(:preserved_object) { create(:preserved_object, current_version: 2) }
  let(:endpoints) { preserved_object.zipped_moab_versions.map(&:zip_endpoint).uniq }
  let(:endpoint) { endpoints.first }
  let(:endpoint2) { endpoints.second }
  let(:zipped_moab_version1) { preserved_object.zipped_moab_versions.where(zip_endpoint: endpoint).first }
  let(:zipped_moab_version2) { preserved_object.zipped_moab_versions.where(zip_endpoint: endpoint).second }
  let(:zipped_moab_version3) { preserved_object.zipped_moab_versions.where(zip_endpoint: endpoint2).first }
  let(:zipped_moab_version4) { preserved_object.zipped_moab_versions.where(zip_endpoint: endpoint2).second }
  let(:audit_class1) { endpoint.audit_class }
  let(:audit_class2) { endpoint2.audit_class }

  before do
    # allow(Audit::ReplicationSupport).to receive(:logger).and_return(logger)
    # creation of MoabRecord triggers archive zip creation, as archive zips are created from moabs
    create(:moab_record, preserved_object: preserved_object, version: preserved_object.current_version)
    allow(Audit::ReplicationSupport).to receive(:check_child_zip_part_attributes).and_return(false)
    allow(audit_class1).to receive(:check_replicated_zipped_moab_version)
    allow(audit_class2).to receive(:check_replicated_zipped_moab_version)
  end

  describe '#results' do
    before do
      allow(Audit::ReplicationSupport).to receive(:check_child_zip_part_attributes).with(zipped_moab_version1, Audit::Results).and_return(true)
      allow(Audit::ReplicationSupport).to receive(:check_child_zip_part_attributes).with(zipped_moab_version3, Audit::Results).and_return(true)
    end

    it 'returns an array of Audit::Results' do
      expect { results }.to change(preserved_object, :last_archive_audit)
      expect(results.length).to eq(2)
      expect(results.first.results_as_string).to match(/actual location: #{endpoint.endpoint_name}/)
      expect(audit_class1).to have_received(:check_replicated_zipped_moab_version).with(zipped_moab_version1, Audit::Results)
      expect(audit_class1).not_to have_received(:check_replicated_zipped_moab_version).with(zipped_moab_version2, Audit::Results)
      expect(audit_class1).not_to have_received(:check_replicated_zipped_moab_version).with(zipped_moab_version3, Audit::Results)
      expect(audit_class2).to have_received(:check_replicated_zipped_moab_version).with(zipped_moab_version3, Audit::Results)
      expect(audit_class2).not_to have_received(:check_replicated_zipped_moab_version).with(zipped_moab_version4, Audit::Results)
      expect(audit_class2).not_to have_received(:check_replicated_zipped_moab_version).with(zipped_moab_version1, Audit::Results)
    end
  end
end
