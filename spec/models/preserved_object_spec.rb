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

  it { is_expected.to have_one(:complete_moab) }
  it { is_expected.to have_db_index(:druid) }
  it { is_expected.to have_db_index(:last_archive_audit) }
  it { is_expected.to validate_presence_of(:druid) }
  it { is_expected.to validate_presence_of(:current_version) }
  it { is_expected.to have_many(:zipped_moab_versions) }

  context 'validation' do
    let(:valid_obj) { described_class.new(required_attributes) }

    it 'is valid with required attributes' do
      expect(valid_obj).to be_valid
    end

    context 'when returning json' do
      subject { valid_obj.to_json }

      it 'does not include id' do
        expect(subject).not_to include '"id"'
      end
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

    describe 'enforces unique constraint on druid' do
      before { described_class.create!(required_attributes) }

      it 'at model level' do
        msg = 'Validation failed: Druid has already been taken'
        expect { described_class.create!(required_attributes) }.to raise_error(ActiveRecord::RecordInvalid, msg)
      end

      it 'at db level' do
        dup_po = described_class.new(druid: druid, current_version: 2)
        expect { dup_po.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  # context 'delegation to s3_key' do
  #   it 'creates the s3_key correctly' do
  #     expect(cm.s3_key).to eq("ab/123/cd/4567/#{druid}.v0001.zip")
  #   end
  # end

  # describe '#druid_version_zip' do
  #   it 'creates an instance of DruidVersionZip' do
  #     expect(cm.druid_version_zip).to be_an_instance_of DruidVersionZip
  #   end
  # end

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

    describe '.archive_check_expired' do
      it 'returns CompleteMoabs that need fixity check' do
        expect(described_class.archive_check_expired.to_a.sort).to eq [preserved_object, old_check_po1, old_check_po2]
      end

      it 'returns no CompleteMoabs with timestamps indicating still-valid fixity check' do
        expect(described_class.archive_check_expired).not_to include(recently_checked_po1, recently_checked_po2)
      end
    end
  end

  describe '#create_zipped_moab_versions!' do
    let!(:preserved_object) { create(:preserved_object, druid: druid, current_version: 3) }
    let(:current_version) { preserved_object.current_version }
    let!(:msr1) { create(:moab_storage_root) }
    let!(:cm1) { create(:complete_moab, preserved_object: preserved_object, version: current_version, moab_storage_root: msr1) }
    let(:zmvs_by_druid) { ZippedMoabVersion.by_druid(druid) }
    let(:zip_endpoints) { ZipEndpoint.all }
    let!(:zip_ep) { zip_endpoints.first }
    let!(:zip_ep2) { zip_endpoints.second }

    before do
      allow(ZipmakerJob).to receive(:perform_later)
      ZippedMoabVersion.destroy_all # a bit contrived, but delete ZMVs auto-created by AR hook, so we can test #create_zipped_moab_versions!
    end

    it "creates ZMVs that don't yet exist for expected versions, but should" do
      expect(ZipmakerJob).to receive(:perform_later).with(preserved_object.druid, 1, cm1.moab_storage_root.storage_location)
      expect(ZipmakerJob).to receive(:perform_later).with(preserved_object.druid, 2, cm1.moab_storage_root.storage_location)
      expect(ZipmakerJob).to receive(:perform_later).with(preserved_object.druid, 3, cm1.moab_storage_root.storage_location)
      expect { preserved_object.create_zipped_moab_versions! }.to change {
        ZipEndpoint.which_need_archive_copy(druid, current_version).to_a.to_set
      }.from([zip_ep, zip_ep2].to_set).to([].to_set).and change {
        zmvs_by_druid.where(version: current_version).count
      }.from(0).to(2)

      expect(zmvs_by_druid.pluck(:version).sort).to eq [1, 1, 2, 2, 3, 3]
    end

    it "creates ZMVs that don't yet exist for new endpoint, but should" do
      expect { preserved_object.create_zipped_moab_versions! }.to change {
        ZipEndpoint.which_need_archive_copy(druid, current_version).to_a.to_set
      }.from([zip_ep, zip_ep2].to_set).to([].to_set).and change {
        zmvs_by_druid.where(version: current_version).count
      }.from(0).to(2)

      new_zip_ep = create(:zip_endpoint)

      expect(ZipmakerJob).to receive(:perform_later).with(preserved_object.druid, 1, msr1.storage_location)
      expect(ZipmakerJob).to receive(:perform_later).with(preserved_object.druid, 2, msr1.storage_location)
      expect(ZipmakerJob).to receive(:perform_later).with(preserved_object.druid, 3, msr1.storage_location)
      expect { preserved_object.create_zipped_moab_versions! }.to change {
        ZipEndpoint.which_need_archive_copy(druid, current_version).to_a
      }.from([new_zip_ep]).to([]).and change {
        zmvs_by_druid.where(version: current_version).count
      }.from(2).to(3)
    end

    it 'creates all versions for ZMV' do
      expect(preserved_object.current_version).to eq 3
      expect { preserved_object.create_zipped_moab_versions! }.to change(ZippedMoabVersion, :count).from(0).to(6)
    end

    it 'if ZMVs already exist, return an empty array' do
      preserved_object.create_zipped_moab_versions!
      expect(preserved_object.create_zipped_moab_versions!).to eq []
    end

    context 'no moabs are both up to date and ok' do
      let(:cm1) do
        create(:complete_moab, preserved_object: preserved_object, version: current_version, status: 'invalid_checksum', moab_storage_root: msr1)
      end

      it 'returns nil and does not attempt to replicate' do
        expect(ZipEndpoint).not_to receive(:which_need_archive_copy)
        expect(ZipmakerJob).not_to receive(:perform_later)
        expect(preserved_object.create_zipped_moab_versions!).to be_nil
      end
    end
  end

  describe '#audit_moab_version_replication!' do
    let!(:preserved_object) { create(:preserved_object, druid: druid, current_version: 3) }

    it 'queues a replication audit job for its CompleteMoab' do
      expect(MoabReplicationAuditJob).to receive(:perform_later).with(preserved_object)
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

    context 'when complete moab is nil' do
      it 'returns 0' do
        expect(preserved_object.total_size_of_moab_version(current_version)).to eq(0)
      end
    end

    context 'when complete moab exists' do
      let!(:cm1) { create(:complete_moab, preserved_object: preserved_object, version: current_version, moab_storage_root: msr) } # rubocop:disable RSpec/LetSetup

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
