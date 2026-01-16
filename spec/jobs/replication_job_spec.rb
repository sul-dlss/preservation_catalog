# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReplicationJob do
  let(:preserved_object) { create(:preserved_object, current_version: 2) }

  before do
    allow(Replication::AuditService).to receive(:call)
    allow(Replication::ReplicateVersionService).to receive(:call)
  end

  it 'audits and replicates each version' do
    expect { described_class.perform_now(preserved_object) }.to change {
      preserved_object.reload.zipped_moab_versions.count
    }.from(0).to(ZipEndpoint.count * 2)
    expect(Replication::AuditService).to have_received(:call).with(preserved_object:)
    expect(Replication::ReplicateVersionService).to have_received(:call).twice
    expect(Replication::ReplicateVersionService).to have_received(:call).with(preserved_object:, version: 1)
    expect(Replication::ReplicateVersionService).to have_received(:call).with(preserved_object:, version: 2)
  end
end
