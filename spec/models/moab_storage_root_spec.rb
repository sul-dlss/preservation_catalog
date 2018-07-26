require 'rails_helper'

RSpec.describe MoabStorageRoot, type: :model do
  let(:default_pres_policies) { [PreservationPolicy.default_policy] }
  let(:druid) { 'ab123cd4567' }
  let!(:moab_storage_root) do
    create(
      :moab_storage_root,
      name: 'storage-root-01',
      storage_location: '/storage_root01'
    )
  end

  it 'is not valid unless it has all required attributes' do
    expect(MoabStorageRoot.new).not_to be_valid
    expect(MoabStorageRoot.new(name: 'aws')).not_to be_valid
    expect(moab_storage_root).to be_valid
  end

  it 'enforces unique constraint on name (model level)' do
    expect do
      MoabStorageRoot.create!(moab_storage_root.attributes.slice('name', 'storage_location'))
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'enforces unique constraint on name (db level)' do
    expect { moab_storage_root.dup.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it { is_expected.to have_many(:complete_moabs) }
  it { is_expected.to have_db_index(:name) }
  it { is_expected.to have_db_index(:storage_location) }
  it { is_expected.to have_and_belong_to_many(:preservation_policies) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:storage_location) }

  describe '.seed_moab_storage_roots_from_config' do
    it 'creates a moab_storage_root for each storage root' do
      HostSettings.storage_roots.each do |storage_root_name, storage_root_location|
        storage_root_attrs = {
          storage_location: File.join(storage_root_location, Settings.moab.storage_trunk),
          preservation_policies: default_pres_policies
        }
        expect(MoabStorageRoot.find_by(name: storage_root_name)).to have_attributes(storage_root_attrs)
      end
    end

    # run it a second time
    it 'does not re-create records that already exist' do
      expect { MoabStorageRoot.seed_moab_storage_roots_from_config(default_pres_policies) }
        .not_to change { MoabStorageRoot.pluck(:name).sort }
        .from(%w[fixture_empty fixture_sr1 fixture_sr2 fixture_sr3 storage-root-01])
    end

    it 'adds new records if there are additions to Settings since the last run' do
      storage_roots_setting = Config::Options.new(
        fixture_sr1: 'spec/fixtures/storage_root01',
        fixture_sr2: 'spec/fixtures/storage_root02',
        fixture_srTest: 'spec/fixtures/storage_root_unit_test'
      )
      allow(HostSettings).to receive(:storage_roots).and_return(storage_roots_setting)

      # run it a second time
      expect { MoabStorageRoot.seed_moab_storage_roots_from_config(default_pres_policies) }
        .to change { MoabStorageRoot.pluck(:name).sort }
        .from(%w[fixture_empty fixture_sr1 fixture_sr2 fixture_sr3 storage-root-01])
        .to(%w[fixture_empty fixture_sr1 fixture_sr2 fixture_sr3 fixture_srTest storage-root-01])
    end
  end

  describe '#validate_expired_checksums!' do
    it 'calls ChecksumValidationJob for each eligible CompleteMoab' do
      allow(Rails.logger).to receive(:info)
      ms_root = create(:moab_storage_root)
      ms_root.complete_moabs = build_list(:complete_moab, 2)
      expect(ChecksumValidationJob).to receive(:perform_later).with(ms_root.complete_moabs.first)
      expect(ChecksumValidationJob).to receive(:perform_later).with(ms_root.complete_moabs.second)
      ms_root.validate_expired_checksums!
    end
  end
end
