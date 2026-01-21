# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MoabRecordCalculations do
  describe '.with_errors' do
    before do
      create(:moab_record, status: :ok)
      create(:moab_record, status: :invalid_moab)
      create(:moab_record, status: :invalid_checksum)
      create(:moab_record, status: :moab_on_storage_not_found)
      create(:moab_record, status: :unexpected_version_on_storage)
      create(:moab_record, status: :validity_unknown)
    end

    it 'returns MoabRecords with error statuses' do
      expect(MoabRecord.with_errors.count).to eq(4)
    end
  end

  describe '.stuck' do
    before do
      create(:moab_record, status: :validity_unknown, updated_at: 2.weeks.ago)
      create(:moab_record, status: :validity_unknown, updated_at: 3.days.ago)
      create(:moab_record, status: :validity_unknown)
      create(:moab_record, status: :ok)
    end

    it 'returns MoabRecords with status of validity_unknown for more than a week' do
      expect(MoabRecord.stuck.count).to eq(1)
    end
  end

  describe '.validity_unknown_count' do
    before do
      create(:moab_record, status: :validity_unknown)
      create(:moab_record, status: :validity_unknown)
      create(:moab_record, status: :ok)
    end

    it 'returns the count of MoabRecords with status of validity_unknown' do
      expect(MoabRecord.validity_unknown_count).to eq(2)
    end
  end

  describe '.expired_checksum_validation_with_grace_count' do
    before do
      # Default expiration is 90 days. Grace is 7 days.
      create(:moab_record, last_checksum_validation: 10.days.ago)
      create(:moab_record, last_checksum_validation: 91.days.ago)
      create(:moab_record, last_checksum_validation: 100.days.ago)
    end

    it 'returns the count of MoabRecords with expired checksum validation audits with grace period' do
      expect(MoabRecord.expired_checksum_validation_with_grace_count).to eq(1)
    end
  end

  describe '.moab_records_by_moab_storage_root' do
    let(:moab_storage_root1) { create(:moab_storage_root) }
    let(:moab_storage_root2) { create(:moab_storage_root) }

    before do
      create(:moab_record, moab_storage_root: moab_storage_root1, status: 'ok', size: 100)
      create_list(:moab_record, 2, moab_storage_root: moab_storage_root1, status: 'invalid_moab', size: 101)
      create_list(:moab_record, 3, moab_storage_root: moab_storage_root1, status: 'invalid_checksum', size: 102)
      create_list(:moab_record, 4, moab_storage_root: moab_storage_root1, status: 'moab_on_storage_not_found', size: 103)
      create_list(:moab_record, 5, moab_storage_root: moab_storage_root1, status: 'unexpected_version_on_storage', size: 104)
      create_list(:moab_record, 6, moab_storage_root: moab_storage_root1, status: 'validity_unknown', size: 105)
      create_list(:moab_record, 7, moab_storage_root: moab_storage_root2, status: 'ok', size: 200)
    end

    it 'returns aggregation of MoabRecords by MoabStorageRoot and a total aggregation' do
      results, total_result = MoabRecord.moab_records_by_moab_storage_root
      result1 = results.find { |r| r.moab_storage_root == moab_storage_root1 }
      result2 = results.find { |r| r.moab_storage_root == moab_storage_root2 }

      expect(result1.total_size).to eq(2170)
      expect(result1.moab_count).to eq(21)
      expect(result1.ok_count).to eq(1)
      expect(result1.invalid_moab_count).to eq(2)
      expect(result1.invalid_checksum_count).to eq(3)
      expect(result1.moab_on_storage_not_found_count).to eq(4)
      expect(result1.unexpected_version_on_storage_count).to eq(5)
      expect(result1.validity_unknown_count).to eq(6)

      expect(result2.total_size).to eq(1400)
      expect(result2.moab_count).to eq(7)
      expect(result2.ok_count).to eq(7)
      expect(result2.invalid_moab_count).to eq(0)
      expect(result2.invalid_checksum_count).to eq(0)
      expect(result2.moab_on_storage_not_found_count).to eq(0)
      expect(result2.unexpected_version_on_storage_count).to eq(0)
      expect(result2.validity_unknown_count).to eq(0)

      expect(total_result.total_size).to eq(3570)
      expect(total_result.moab_count).to eq(28)
      expect(total_result.ok_count).to eq(8)
    end
  end
end
