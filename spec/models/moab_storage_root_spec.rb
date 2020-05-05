# frozen_string_literal: true

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
    expect(described_class.new).not_to be_valid
    expect(described_class.new(name: 'aws')).not_to be_valid
    expect(moab_storage_root).to be_valid
  end

  describe 'enforces unique constraint on name' do
    it 'at model level' do
      msg = 'Validation failed: Name has already been taken'
      expect do
        described_class.create!(name: 'storage-root-01', storage_location: '/storage_root02')
      end.to raise_error(ActiveRecord::RecordInvalid, msg)
    end

    it 'at db level' do
      expect { moab_storage_root.dup.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'enforces unique constraint on storage_location' do
    it 'at model level' do
      msg = 'Validation failed: Storage location has already been taken'
      expect do
        described_class.create!(name: 'storage-root-03', storage_location: '/storage_root01')
      end.to raise_error(ActiveRecord::RecordInvalid, msg)
    end

    it 'at db level' do
      dup_moab_storage_root = described_class.new(name: 'storage-root-03', storage_location: '/storage_root01')
      expect { dup_moab_storage_root.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  it { is_expected.to have_many(:complete_moabs) }
  it { is_expected.to have_db_index(:name) }
  it { is_expected.to have_db_index(:storage_location) }
  it { is_expected.to have_and_belong_to_many(:preservation_policies) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:storage_location) }

  describe '.seed_from_config' do
    # assumes seeding already ran for the suite, we run it a again
    it 'does not re-create records that already exist' do
      expect { described_class.seed_from_config(default_pres_policies) }
        .not_to change { described_class.pluck(:name).sort }
        .from(%w[fixture_empty fixture_sr1 fixture_sr2 fixture_sr3 storage-root-01])
    end

    it 'adds new records from Settings (but does not delete)' do
      storage_roots_setting = Config::Options.new(
        fixture_sr1: 'spec/fixtures/storage_root01',
        fixture_sr2: 'spec/fixtures/storage_root02',
        fixture_srTest: 'spec/fixtures/storage_root_unit_test'
      )
      allow(Settings.storage_root_map).to receive(:default).and_return(storage_roots_setting)

      expect { described_class.seed_from_config(default_pres_policies) }
        .to change { described_class.pluck(:name).sort }
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
        expect(CatalogToMoabJob).to receive(:perform_later).with(msr.complete_moabs.first)
        expect(CatalogToMoabJob).to receive(:perform_later).with(msr.complete_moabs.second)
        msr.c2m_check!
      end
    end

    describe '#m2c_check!' do
      it 'calls MoabToCatalogJob for each eligible on-disk Moab' do
        msr.storage_location = 'spec/fixtures/storage_root01/sdr2objects' # using enumerated fixtures
        expect(MoabToCatalogJob).to receive(:perform_later)
          .with(msr, 'bj102hs9687')
        expect(MoabToCatalogJob).to receive(:perform_later)
          .with(msr, 'bz514sm9647')
        expect(MoabToCatalogJob).to receive(:perform_later)
          .with(msr, 'jj925bx9565')
        msr.m2c_check!
      end
    end
  end
end
