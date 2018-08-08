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

  context 'job wrappers' do
    let(:msr) { create(:moab_storage_root) }

    before do
      allow(Rails.logger).to receive(:info)
      msr.complete_moabs = build_list(:complete_moab, 2)
    end

    describe '#validate_expired_checksums!' do
      it 'calls ChecksumValidationJob for each eligible CompleteMoab' do
        expect(ChecksumValidationJob).to receive(:perform_later).with(msr.complete_moabs.first)
        expect(ChecksumValidationJob).to receive(:perform_later).with(msr.complete_moabs.second)
        msr.validate_expired_checksums!
      end
    end

    describe '#c2m_check!' do
      it 'calls CatalogToMoabJob for each eligible CompleteMoab' do
        expect(CatalogToMoabJob).to receive(:perform_later).with(msr.complete_moabs.first, msr.storage_location)
        expect(CatalogToMoabJob).to receive(:perform_later).with(msr.complete_moabs.second, msr.storage_location)
        msr.c2m_check!
      end
    end

    describe '#m2c_check!' do
      it 'calls MoabToCatalogJob for each eligible on-disk Moab' do
        msr.storage_location = 'spec/fixtures/storage_root01/sdr2objects' # using enumerated fixtures
        expect(MoabToCatalogJob).to receive(:perform_later)
          .with(msr, 'bj102hs9687', "#{msr.storage_location}/bj/102/hs/9687/bj102hs9687")
        expect(MoabToCatalogJob).to receive(:perform_later)
          .with(msr, 'bz514sm9647', "#{msr.storage_location}/bz/514/sm/9647/bz514sm9647")
        expect(MoabToCatalogJob).to receive(:perform_later)
          .with(msr, 'jj925bx9565', "#{msr.storage_location}/jj/925/bx/9565/jj925bx9565")
        msr.m2c_check!
      end
    end
  end
end
