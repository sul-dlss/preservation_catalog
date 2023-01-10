# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StorageRootMigrationService do
  let(:to_storage_root) { create(:moab_storage_root) }

  let(:from_storage_root) { moab_record1.moab_storage_root }

  let(:moab_record1) {
    create(:moab_record, status: 'ok',
                         last_moab_validation: Time.now,
                         last_checksum_validation: Time.now)
  }

  let(:moab_record2) { create(:moab_record, status: 'invalid_moab', moab_storage_root: from_storage_root) }

  let(:moab_record3) { create(:moab_record) }

  it 'migrates the storage root' do
    # Before migration
    expect(moab_record1.moab_storage_root).to eq(moab_record2.moab_storage_root)
    expect(moab_record1.moab_storage_root).not_to eq(moab_record3.moab_storage_root)

    druids = described_class.new(from_storage_root.name, to_storage_root.name).migrate
    expect(druids).to include(moab_record1.preserved_object.druid, moab_record2.preserved_object.druid)

    moab_record1.reload
    moab_record2.reload

    expect(moab_record1.moab_storage_root).to eq(to_storage_root)
    expect(moab_record1.from_moab_storage_root).to eq(from_storage_root)
    expect(moab_record2.moab_storage_root).to eq(to_storage_root)
    expect(moab_record2.from_moab_storage_root).to eq(from_storage_root)
  end

  it 'resets field values' do
    described_class.new(from_storage_root.name, to_storage_root.name).migrate

    moab_record1.reload

    expect(moab_record1.status).to eq('validity_unknown')
    expect(moab_record1.status_details).to be_nil
    expect(moab_record1.last_moab_validation).to be_nil
    expect(moab_record1.last_checksum_validation).to be_nil
  end

  it 'queues checksum validation jobs' do
    allow(Audit::ChecksumValidationJob).to receive(:perform_later).with(moab_record1)
    allow(Audit::ChecksumValidationJob).to receive(:perform_later).with(moab_record2)
    allow(Audit::ChecksumValidationJob).to receive(:perform_later).with(moab_record3)
    described_class.new(from_storage_root.name, to_storage_root.name).migrate
    expect(Audit::ChecksumValidationJob).to have_received(:perform_later).with(moab_record1)
    expect(Audit::ChecksumValidationJob).to have_received(:perform_later).with(moab_record2)
    expect(Audit::ChecksumValidationJob).not_to have_received(:perform_later).with(moab_record3)
  end

  it 'does not migrate moabs on other storage roots' do
    # Before migration
    orig_moab_record3_storage_root = moab_record3.moab_storage_root

    described_class.new(from_storage_root.name, to_storage_root.name).migrate

    moab_record3.reload

    expect(moab_record3.moab_storage_root).to eq(orig_moab_record3_storage_root)
    expect(moab_record3.from_moab_storage_root).to be_nil
  end
end
