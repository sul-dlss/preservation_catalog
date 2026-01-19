# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MoabRecordCalculations do
  describe '.errors_count' do
    before do
      create(:moab_record, status: :ok)
      create(:moab_record, status: :invalid_moab)
      create(:moab_record, status: :invalid_checksum)
      create(:moab_record, status: :moab_on_storage_not_found)
      create(:moab_record, status: :unexpected_version_on_storage)
      create(:moab_record, status: :validity_unknown)
    end

    it 'returns the count of MoabRecords with error statuses' do
      expect(MoabRecord.errors_count).to eq(4)
    end
  end

  describe '.stuck_count' do
    before do
      create(:moab_record, status: :validity_unknown, updated_at: 2.weeks.ago)
      create(:moab_record, status: :validity_unknown, updated_at: 3.days.ago)
      create(:moab_record, status: :validity_unknown)
      create(:moab_record, status: :ok)
    end

    it 'returns the count of MoabRecords with status of validity_unknown for more than a week' do
      expect(MoabRecord.stuck_count).to eq(2)
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
end
