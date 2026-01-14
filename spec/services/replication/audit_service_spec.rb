# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Replication::AuditService do
  subject(:results_list) { described_class.call(preserved_object:) }

  let(:preserved_object) { create(:preserved_object) }

  let(:zip_endpoint_east) { create(:zip_endpoint, endpoint_name: 's3-east') }
  let(:zip_endpoint_west) { create(:zip_endpoint, endpoint_name: 's3-west') }
  let!(:zipped_moab_version_east) { create(:zipped_moab_version, preserved_object:, zip_endpoint: zip_endpoint_east) }
  let!(:zipped_moab_version_west) { create(:zipped_moab_version, preserved_object:, zip_endpoint: zip_endpoint_west) }

  before do
    allow(ZipEndpoint).to receive(:all).and_return([zip_endpoint_east, zip_endpoint_west])
    allow(Replication::ZippedMoabVersionAuditService).to receive(:call)
  end

  it 'returns audit results for each zip endpoint' do
    expect(results_list.length).to eq 2
    endpoint_names = results_list.map { |result| result.moab_storage_root.endpoint_name }
    expect(endpoint_names).to contain_exactly('s3-east', 's3-west')

    expect(Replication::ZippedMoabVersionAuditService).to have_received(:call)
      .with(zipped_moab_version: zipped_moab_version_east, results: Results)
    expect(Replication::ZippedMoabVersionAuditService).to have_received(:call)
      .with(zipped_moab_version: zipped_moab_version_west, results: Results)
  end
end
