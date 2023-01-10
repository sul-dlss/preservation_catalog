# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MoabStorageRoot do
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

  describe 'name attribute' do
    context 'at model level' do
      it 'must be unique' do
        msg = 'Validation failed: Name has already been taken'
        expect do
          described_class.create!(name: 'storage-root-01', storage_location: '/storage_root02')
        end.to raise_error(ActiveRecord::RecordInvalid, msg)
      end
    end

    context 'at db level' do
      it 'must be unique' do
        expect { moab_storage_root.dup.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe 'storage_location attribute' do
    context 'at model level' do
      it 'must be unique' do
        msg = 'Validation failed: Storage location has already been taken'
        expect do
          described_class.create!(name: 'storage-root-03', storage_location: '/storage_root01')
        end.to raise_error(ActiveRecord::RecordInvalid, msg)
      end
    end

    context 'at db level' do
      it 'must be unique' do
        dup_moab_storage_root = described_class.new(name: 'storage-root-03', storage_location: '/storage_root01')
        expect { dup_moab_storage_root.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  it { is_expected.to have_many(:moab_records) }
  it { is_expected.to have_db_index(:name) }
  it { is_expected.to have_db_index(:storage_location) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:storage_location) }

  describe '.seed_from_config' do
    # assumes seeding already ran for the suite, we run it a again
    it 'does not re-create records that already exist' do
      expect { described_class.seed_from_config }
        .not_to change { described_class.pluck(:name).sort }
        .from(%w[fixture_empty fixture_sr1 fixture_sr2 fixture_sr3 fixture_srA storage-root-01])
    end

    it 'adds new records from Settings (but does not delete)' do
      storage_roots_setting = Config::Options.new(
        fixture_sr1: 'spec/fixtures/storage_root01',
        fixture_sr2: 'spec/fixtures/storage_root02',
        fixture_srTest: 'spec/fixtures/storage_root_unit_test'
      )
      allow(Settings.storage_root_map).to receive(:default).and_return(storage_roots_setting)

      expect { described_class.seed_from_config }
        .to change { described_class.pluck(:name).sort }
        .from(%w[fixture_empty fixture_sr1 fixture_sr2 fixture_sr3 fixture_srA storage-root-01])
        .to(%w[fixture_empty fixture_sr1 fixture_sr2 fixture_sr3 fixture_srA fixture_srTest storage-root-01])
    end
  end

  context 'job wrappers' do
    let(:msr) { create(:moab_storage_root) }

    before do
      allow(Rails.logger).to receive(:info)
      msr.moab_records = build_list(:moab_record, 2)
    end

    describe '#validate_expired_checksums!' do
      it 'calls Audit::ChecksumValidationJob for each eligible MoabRecord' do
        expect(Audit::ChecksumValidationJob).to receive(:perform_later).with(msr.moab_records.first)
        expect(Audit::ChecksumValidationJob).to receive(:perform_later).with(msr.moab_records.second)
        msr.validate_expired_checksums!
      end
    end

    describe '#c2m_check!' do
      it 'calls Audit::CatalogToMoabJob for each eligible MoabRecord' do
        expect(Audit::CatalogToMoabJob).to receive(:perform_later).with(msr.moab_records.first)
        expect(Audit::CatalogToMoabJob).to receive(:perform_later).with(msr.moab_records.second)
        msr.c2m_check!
      end
    end

    describe '#m2c_check!' do
      it 'calls Audit::MoabToCatalogJob for each eligible on-disk Moab' do
        msr.storage_location = 'spec/fixtures/storage_root01/sdr2objects' # using enumerated fixtures
        expect(Audit::MoabToCatalogJob).to receive(:perform_later)
          .with(msr, 'bj102hs9687')
        expect(Audit::MoabToCatalogJob).to receive(:perform_later)
          .with(msr, 'bz514sm9647')
        expect(Audit::MoabToCatalogJob).to receive(:perform_later)
          .with(msr, 'jj925bx9565')
        msr.m2c_check!
      end
    end
  end
end
