# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::AuditService do
  let(:storage_root) { create(:moab_storage_root) }
  let(:outer_class) do
    Class.new do
      include Dashboard::AuditService
    end
  end

  describe '#validate_moab_audit_ok?' do
    context 'when there are CompleteMoabs with invalid_moab status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'invalid_moab')
        create(:complete_moab, status: 'ok')
      end

      it 'returns false' do
        expect(outer_class.new.validate_moab_audit_ok?).to be false
      end
    end

    context 'when there are CompleteMoabs with online_moab_not_found status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'online_moab_not_found')
      end

      it 'returns false' do
        expect(outer_class.new.validate_moab_audit_ok?).to be false
      end
    end

    context 'when there are no CompleteMoabs with either online_moab_not_found or invalid_moab status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'invalid_checksum')
      end

      it 'returns true' do
        expect(outer_class.new.validate_moab_audit_ok?).to be true
      end
    end
  end

  describe '#catalog_to_moab_audit_ok?' do
    context 'when there are CompleteMoabs with unexpected_version_on_storage status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'unexpected_version_on_storage')
        create(:complete_moab, status: 'ok')
      end

      it 'returns false' do
        expect(outer_class.new.catalog_to_moab_audit_ok?).to be false
      end
    end

    context 'when there are CompleteMoabs with online_moab_not_found status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'online_moab_not_found')
      end

      it 'returns false' do
        expect(outer_class.new.catalog_to_moab_audit_ok?).to be false
      end
    end

    context 'when there are no CompleteMoabs with either online_moab_not_found or unexpected_version_on_storage status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'invalid_checksum')
      end

      it 'returns true' do
        expect(outer_class.new.catalog_to_moab_audit_ok?).to be true
      end
    end
  end

  describe '#moab_to_catalog_audit_ok?' do
    before do
      create(:complete_moab, status: 'ok')
      create(:complete_moab, status: 'ok')
    end

    context 'when status other than ok for at least one CompleteMoab' do
      before do
        create(:complete_moab, status: 'unexpected_version_on_storage')
      end

      it 'returns false' do
        expect(outer_class.new.moab_to_catalog_audit_ok?).to be false
      end
    end

    context 'when all CompleteMoabs have status ok' do
      it 'returns true' do
        expect(outer_class.new.moab_to_catalog_audit_ok?).to be true
      end
    end
  end

  describe '#moab_checksum_validation_audit_ok?' do
    context 'when there are CompleteMoabs with online_moab_not_found status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'invalid_checksum')
      end

      it 'returns false' do
        expect(outer_class.new.moab_checksum_validation_audit_ok?).to be false
      end
    end

    context 'when there are no CompleteMoabs with either online_moab_not_found or unexpected_version_on_storage status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'unexpected_version_on_storage')
      end

      it 'returns true' do
        expect(outer_class.new.moab_checksum_validation_audit_ok?).to be true
      end
    end
  end

  describe '#catalog_to_archive_audit_ok?' do
    before do
      create(:zip_part, status: 'ok')
      create(:zip_part, status: 'ok')
    end

    context 'when all ZipParts have ok status' do
      it 'is true' do
        expect(outer_class.new.catalog_to_archive_audit_ok?).to be true
      end
    end

    context 'when all ZipParts do not have ok status' do
      before do
        create(:zip_part, status: 'replicated_checksum_mismatch')
      end

      it 'is false' do
        expect(outer_class.new.catalog_to_archive_audit_ok?).to be false
      end
    end
  end

  describe '#moab_audit_age_threshold' do
    it 'returns string version of MOAB_LAST_VERSION_AUDIT_THRESHOLD ago' do
      expect(outer_class.new.moab_audit_age_threshold).to be_a(String)
      result = DateTime.parse(outer_class.new.moab_audit_age_threshold)
      expect(result).to be <= DateTime.now - described_class::MOAB_LAST_VERSION_AUDIT_THRESHOLD
    end
  end

  context 'when at least one CompleteMoab has last_version_audit older than MOAB_LAST_VERSION_AUDIT_THRESHOLD' do
    before do
      create(:complete_moab, last_version_audit: 45.days.ago)
      create(:complete_moab, last_version_audit: 1.day.ago)
      create(:complete_moab, last_version_audit: 2.days.ago)
      create(:complete_moab, last_version_audit: 30.days.ago)
    end

    describe '#num_moab_audits_older_than_threshold' do
      it 'returns a number greater than 0' do
        expect(outer_class.new.num_moab_audits_older_than_threshold).to be > 0
        expect(outer_class.new.num_moab_audits_older_than_threshold).to eq 2
      end
    end

    describe '#moab_audits_older_than_threshold?' do
      it 'is true' do
        expect(outer_class.new.moab_audits_older_than_threshold?).to be true
      end
    end
  end

  context 'when no CompleteMoabs have last_version_audit older than MOAB_LAST_VERSION_AUDIT_THRESHOLD' do
    before do
      create(:complete_moab, last_version_audit: 5.days.ago)
    end

    describe '#num_moab_audits_older_than_threshold' do
      it 'returns 0' do
        expect(outer_class.new.num_moab_audits_older_than_threshold).to eq 0
      end
    end

    describe '#moab_audits_older_than_threshold?' do
      it 'is false' do
        expect(outer_class.new.moab_audits_older_than_threshold?).to be false
      end
    end
  end

  describe '#replication_audit_age_threshold' do
    it 'returns string version of REPLICATION_AUDIT_THRESHOLD ago' do
      expect(outer_class.new.replication_audit_age_threshold).to be_a(String)
      result = DateTime.parse(outer_class.new.replication_audit_age_threshold)
      expect(result).to be <= DateTime.now - described_class::REPLICATION_AUDIT_THRESHOLD
    end
  end

  context 'when at least one PreservedObject has archive_check_expired' do
    before do
      create(:preserved_object, last_archive_audit: 95.days.ago)
      create(:preserved_object) # last_archive_audit is nil so it counts
      create(:preserved_object, last_archive_audit: 132.days.ago)
      create(:preserved_object, last_archive_audit: 5.days.ago)
    end

    describe '#num_replication_audits_older_than_threshold' do
      it 'returns a number greater than 0' do
        expect(outer_class.new.num_replication_audits_older_than_threshold).to be > 0
        expect(outer_class.new.num_replication_audits_older_than_threshold).to eq 3
      end
    end

    describe '#replication_audits_older_than_threshold?' do
      it 'is true' do
        expect(outer_class.new.replication_audits_older_than_threshold?).to be true
      end
    end
  end

  context 'when no PreservedObjects have last_version_audit older than archive_check_expired' do
    before do
      create(:preserved_object, last_archive_audit: 5.days.ago)
      create(:preserved_object, last_archive_audit: 2.days.ago)
    end

    describe '#num_replication_audits_older_than_threshold' do
      it 'returns 0' do
        expect(outer_class.new.num_replication_audits_older_than_threshold).to eq 0
      end
    end

    describe '#replication_audits_older_than_threshold?' do
      it 'is false' do
        expect(outer_class.new.replication_audits_older_than_threshold?).to be false
      end
    end
  end
end
