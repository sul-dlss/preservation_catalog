# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PreservedObject do
  let(:druid) { 'bc123df4567' }
  let(:now) { Time.now.utc }

  let(:required_attributes) do
    {
      druid: druid,
      current_version: 1
    }
  end

  context 'validation' do
    let(:valid_obj) { described_class.new(required_attributes) }

    it 'is valid with required attributes' do
      expect(valid_obj).to be_valid
    end

    it 'is not valid without all required attributes' do
      expect(described_class.new).not_to be_valid
      expect(described_class.new(current_version: 1)).not_to be_valid
    end

    it 'with bad druid is invalid' do
      expect(described_class.new(required_attributes.merge(druid: 'FOObarzubaz'))).not_to be_valid
      expect(described_class.new(required_attributes.merge(druid: 'b123cd4567'))).not_to be_valid
      expect(described_class.new(required_attributes.merge(druid: 'ab123cd45678'))).not_to be_valid
    end

    it 'with druid prefix is invalid' do
      expect(described_class.new(required_attributes.merge(druid: 'druid:ab123cd4567'))).not_to be_valid
      expect(described_class.new(required_attributes.merge(druid: 'DRUID:ab123cd4567'))).not_to be_valid
    end
  end

  describe '.archive_check_expired' do
    let!(:preserved_object) { create(:preserved_object, druid: druid) }
    let(:archive_ttl) { Settings.preservation_policy.archive_ttl }
    let!(:old_check_po1) do
      create(:preserved_object, current_version: 6, last_archive_audit: now - (archive_ttl * 2))
    end
    let!(:old_check_po2) do
      create(:preserved_object, current_version: 7, last_archive_audit: now - archive_ttl - 1.second)
    end
    let!(:recently_checked_po1) do
      create(:preserved_object, current_version: 8, last_archive_audit: now - archive_ttl + 1.second)
    end
    let!(:recently_checked_po2) do
      create(:preserved_object, current_version: 9, last_archive_audit: now - (archive_ttl * 0.1))
    end

    it 'returns MoabRecords that need fixity check' do
      expect(described_class.archive_check_expired.to_a.sort).to eq [preserved_object, old_check_po1, old_check_po2]
    end

    it 'returns no MoabRecords with timestamps indicating still-valid fixity check' do
      expect(described_class.archive_check_expired).not_to include(recently_checked_po1, recently_checked_po2)
    end
  end

  describe '#populate_zipped_moab_versions!' do
    let(:preserved_object) { create(:preserved_object, druid: druid, current_version:) }

    let(:zip_endpoint) { ZipEndpoint.first }
    let(:zip_endpoint_count) { ZipEndpoint.count }
    let(:current_version) { 2 }

    before do
      create(:zipped_moab_version, preserved_object: preserved_object, version: 1, zip_endpoint: zip_endpoint)
    end

    it 'creates missing ZippedMoabVersions for all versions and all ZipEndpoints' do
      new_zipped_moab_versions = preserved_object.populate_zipped_moab_versions!
      expect(new_zipped_moab_versions.size).to eq((zip_endpoint_count * current_version) - 1)

      expect(preserved_object.reload.zipped_moab_versions.count).to eq(zip_endpoint_count * current_version)
      expect(preserved_object.zipped_moab_versions.where(version: 1).count).to eq zip_endpoint_count
      expect(preserved_object.zipped_moab_versions.where(version: 2).count).to eq zip_endpoint_count
      expect(preserved_object.zipped_moab_versions.where(zip_endpoint: zip_endpoint).count).to eq current_version
    end
  end

  describe '#audit_moab_version_replication!' do
    let!(:preserved_object) { create(:preserved_object, druid: druid, current_version: 3) }

    it 'queues a replication audit job for its MoabRecord' do
      expect(Audit::ReplicationAuditJob).to receive(:perform_later).with(preserved_object)
      preserved_object.audit_moab_version_replication!
    end
  end

  describe '#daily_check_count' do
    before do
      allow(described_class).to receive(:count).and_return(1000)
    end

    it 'calculates the number of objects to check per day' do
      expect(described_class.daily_check_count).to eq 11
    end
  end

  describe '#total_size_of_moab_version' do
    let(:druid) { 'bz514sm9647' }
    let(:preserved_object) { create(:preserved_object, druid: druid, current_version: current_version) }
    let(:current_version) { 3 }

    context 'when MoabRecord is nil' do
      it 'returns 0' do
        expect(preserved_object.total_size_of_moab_version(current_version)).to eq(0)
      end
    end

    context 'when MoabRecord exists' do
      let!(:moab_rec1) { create(:moab_record, preserved_object: preserved_object, version: current_version, moab_storage_root: msr) } # rubocop:disable RSpec/LetSetup

      context 'when moab version path does not exist' do
        let(:msr) { create(:moab_storage_root) }

        it 'raises a runtime error' do
          expect { preserved_object.total_size_of_moab_version(current_version) }.to raise_error(
            RuntimeError,
            /Moab version does not exist:/
          )
        end
      end

      context 'when moab version exists' do
        let(:msr) { MoabStorageRoot.find_by!(storage_location: 'spec/fixtures/storage_root01/sdr2objects') }

        it 'returns the sum of the file sizes' do
          expect(preserved_object.total_size_of_moab_version(current_version)).to eq(37_989)
        end
      end
    end
  end
end
