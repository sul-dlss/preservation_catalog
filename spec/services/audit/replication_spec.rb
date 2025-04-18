# frozen_string_literal: true

require 'rails_helper'

describe Audit::Replication do
  let(:results) { described_class.results(preserved_object) }

  let(:preserved_object) { create(:preserved_object, current_version: 2) }
  let(:endpoints) { preserved_object.zipped_moab_versions.map(&:zip_endpoint).uniq }
  let(:endpoint) { endpoints.first }
  let(:endpoint2) { endpoints.second }
  let(:endpoint3) { endpoints.third }
  let(:zipped_moab_version_ep1_v1) { preserved_object.zipped_moab_versions.find_by!(zip_endpoint: endpoint, version: 1) }
  let(:zipped_moab_version_ep1_v2) { preserved_object.zipped_moab_versions.find_by!(zip_endpoint: endpoint, version: 2) }
  let(:zipped_moab_version_ep2_v1) { preserved_object.zipped_moab_versions.find_by!(zip_endpoint: endpoint2, version: 1) }
  let(:zipped_moab_version_ep2_v2) { preserved_object.zipped_moab_versions.find_by!(zip_endpoint: endpoint2, version: 2) }
  let(:zipped_moab_version_ep3_v1) { preserved_object.zipped_moab_versions.find_by!(zip_endpoint: endpoint3, version: 1) }
  let(:zipped_moab_version_ep3_v2) { preserved_object.zipped_moab_versions.find_by!(zip_endpoint: endpoint3, version: 2) }
  let(:audit_class1) { endpoint.audit_class }
  let(:audit_class2) { endpoint2.audit_class }
  let(:audit_class3) { endpoint3.audit_class }

  before do
    # creation of MoabRecord triggers archive zip creation, as archive zips are created from moabs
    create(:moab_record, preserved_object: preserved_object, version: preserved_object.current_version)
    allow(Audit::ReplicationSupport).to receive(:check_child_zip_part_attributes).and_return(false) # default to faking non-existence of child parts
    allow(audit_class1).to receive(:check_replicated_zipped_moab_version)
    allow(audit_class2).to receive(:check_replicated_zipped_moab_version)
    allow(audit_class3).to receive(:check_replicated_zipped_moab_version)
  end

  describe '#results' do
    it 'returns an array of Audit::Results of the expected length' do
      expect { results }.to change(preserved_object, :last_archive_audit)
      expect(results.length).to eq(Settings.zip_endpoints.keys.size)
    end

    it 'reports on versions that we expect to be replicated' do
      expect(results.first.results_as_string).to match(/actual location: #{endpoint.endpoint_name}/)
      expect(results.second.results_as_string).to match(/actual location: #{endpoint2.endpoint_name}/)
      expect(results.third.results_as_string).to match(/actual location: #{endpoint3.endpoint_name}/)
    end
  end

  describe 'audit class' do
    before do
      # but override default allow and fake existence of v1 parts for all 3 endpoints
      allow(Audit::ReplicationSupport).to receive(:check_child_zip_part_attributes).with(zipped_moab_version_ep1_v1, Audit::Results).and_return(true)
      allow(Audit::ReplicationSupport).to receive(:check_child_zip_part_attributes).with(zipped_moab_version_ep2_v1, Audit::Results).and_return(true)
      allow(Audit::ReplicationSupport).to receive(:check_child_zip_part_attributes).with(zipped_moab_version_ep3_v1, Audit::Results).and_return(true)
      results
    end

    it 'checks replication for its endpoints for parts that we think are replicated' do
      expect(audit_class1).to have_received(:check_replicated_zipped_moab_version).with(zipped_moab_version_ep1_v1, Audit::Results)
      expect(audit_class2).to have_received(:check_replicated_zipped_moab_version).with(zipped_moab_version_ep2_v1, Audit::Results)
      expect(audit_class3).to have_received(:check_replicated_zipped_moab_version).with(zipped_moab_version_ep3_v1, Audit::Results)
    end

    it 'does not check replication for versions that we have not recorded as replicated' do
      expect(audit_class1).not_to have_received(:check_replicated_zipped_moab_version).with(zipped_moab_version_ep1_v2, Audit::Results)
      expect(audit_class2).not_to have_received(:check_replicated_zipped_moab_version).with(zipped_moab_version_ep2_v2, Audit::Results)
      expect(audit_class3).not_to have_received(:check_replicated_zipped_moab_version).with(zipped_moab_version_ep3_v2, Audit::Results)
    end

    it 'does not check replication for endpoints for which it is not configured' do
      expect(audit_class1).not_to have_received(:check_replicated_zipped_moab_version).with(zipped_moab_version_ep2_v1, Audit::Results)
      expect(audit_class1).not_to have_received(:check_replicated_zipped_moab_version).with(zipped_moab_version_ep3_v1, Audit::Results)
      expect(audit_class2).not_to have_received(:check_replicated_zipped_moab_version).with(zipped_moab_version_ep1_v1, Audit::Results)
      expect(audit_class2).not_to have_received(:check_replicated_zipped_moab_version).with(zipped_moab_version_ep3_v1, Audit::Results)
      expect(audit_class3).not_to have_received(:check_replicated_zipped_moab_version).with(zipped_moab_version_ep1_v1, Audit::Results)
      expect(audit_class3).not_to have_received(:check_replicated_zipped_moab_version).with(zipped_moab_version_ep2_v1, Audit::Results)
    end
  end
end
