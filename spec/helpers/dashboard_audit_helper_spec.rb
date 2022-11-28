# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DashboardAuditHelper do
  let(:storage_root) { create(:moab_storage_root) }

  describe '#validate_moab_audit_ok?' do
    context 'when there are CompleteMoabs with invalid_moab status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'invalid_moab')
        create(:complete_moab, status: 'ok')
      end

      it 'returns false' do
        expect(helper.validate_moab_audit_ok?).to be false
      end
    end

    context 'when there are CompleteMoabs with online_moab_not_found status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'online_moab_not_found')
      end

      it 'returns false' do
        expect(helper.validate_moab_audit_ok?).to be false
      end
    end

    context 'when there are no CompleteMoabs with either online_moab_not_found or invalid_moab status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'invalid_checksum')
      end

      it 'returns true' do
        expect(helper.validate_moab_audit_ok?).to be true
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
        expect(helper.catalog_to_moab_audit_ok?).to be false
      end
    end

    context 'when there are CompleteMoabs with online_moab_not_found status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'online_moab_not_found')
      end

      it 'returns false' do
        expect(helper.catalog_to_moab_audit_ok?).to be false
      end
    end

    context 'when there are no CompleteMoabs with either online_moab_not_found or unexpected_version_on_storage status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'invalid_checksum')
      end

      it 'returns true' do
        expect(helper.catalog_to_moab_audit_ok?).to be true
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
        expect(helper.moab_to_catalog_audit_ok?).to be false
      end
    end

    context 'when all CompleteMoabs have status ok' do
      it 'returns true' do
        expect(helper.moab_to_catalog_audit_ok?).to be true
      end
    end
  end

  describe '#checksum_validation_audit_ok?' do
    context 'when there are CompleteMoabs with online_moab_not_found status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'invalid_checksum')
      end

      it 'returns false' do
        expect(helper.checksum_validation_audit_ok?).to be false
      end
    end

    context 'when there are no CompleteMoabs with either online_moab_not_found or unexpected_version_on_storage status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'unexpected_version_on_storage')
      end

      it 'returns true' do
        expect(helper.checksum_validation_audit_ok?).to be true
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
        expect(helper.catalog_to_archive_audit_ok?).to be true
      end
    end

    context 'when all ZipParts do not have ok status' do
      before do
        create(:zip_part, status: 'replicated_checksum_mismatch')
      end

      it 'is false' do
        expect(helper.catalog_to_archive_audit_ok?).to be false
      end
    end
  end
end
