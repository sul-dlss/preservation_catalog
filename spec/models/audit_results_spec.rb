# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuditResults do
  let(:actual_version) { 6 }
  let(:audit_results) { described_class.new(druid: druid, actual_version: actual_version, moab_storage_root: ms_root) }
  let(:druid) { 'ab123cd4567' }
  let(:ms_root) { MoabStorageRoot.find_by(storage_location: 'spec/fixtures/storage_root01/sdr2objects') }

  describe '#add_result' do
    it 'can take a single result code argument and adds a hash entry to the results' do
      expect(audit_results.results.size).to eq 0
      code = AuditResults::CM_PO_VERSION_MISMATCH
      addl_hash = { cm_version: 1, po_version: 2 }
      audit_results.add_result(code, addl_hash)
      expect(audit_results.results.size).to eq 1
      exp_msg = AuditResults::RESPONSE_CODE_TO_MESSAGES[code] % addl_hash
      expect(audit_results.results.first).to eq code => exp_msg
    end

    it 'can take a second msg_args argument' do
      code = AuditResults::VERSION_MATCHES
      audit_results.add_result(code, 'foo')
      expect(audit_results.results.size).to eq 1
      expect(audit_results.results.first).to eq code => 'actual version (6) matches foo db version'
    end
  end

  describe '#remove_db_updated_results' do
    before do
      code = AuditResults::CM_PO_VERSION_MISMATCH
      result_msg_args = { cm_version: 1, po_version: 2 }
      audit_results.add_result(code, result_msg_args)
      code = AuditResults::CM_STATUS_CHANGED
      result_msg_args = { old_status: 'ok', new_status: 'invalid_moab' }
      audit_results.add_result(code, result_msg_args)
      code = AuditResults::CREATED_NEW_OBJECT
      audit_results.add_result(code)
      code = AuditResults::INVALID_MOAB
      audit_results.add_result(code, 'foo')
    end

    it 'removes results matching DB_UPDATED_CODES' do
      expect(audit_results.results.size).to eq 4
      audit_results.remove_db_updated_results
      expect(audit_results.results.size).to eq 2
      audit_results.results.each do |result_hash|
        expect(AuditResults::DB_UPDATED_CODES).not_to include(result_hash.keys.first)
      end
      expect(audit_results.results).not_to include(a_hash_including(AuditResults::CREATED_NEW_OBJECT))
      expect(audit_results.results).not_to include(a_hash_including(AuditResults::CM_STATUS_CHANGED))
    end

    it 'keeps results not matching DB_UPDATED_CODES' do
      audit_results.remove_db_updated_results
      expect(audit_results.results).to include(a_hash_including(AuditResults::CM_PO_VERSION_MISMATCH))
      expect(audit_results.results).to include(a_hash_including(AuditResults::INVALID_MOAB))
    end
  end

  describe '#contains_result_code?' do
    it 'returns true if the result code is there, false if not' do
      expect(audit_results.results.size).to eq 0
      added_code = AuditResults::CM_PO_VERSION_MISMATCH
      other_code = AuditResults::VERSION_MATCHES
      audit_results.add_result(added_code, cm_version: 1, po_version: 2)
      expect(audit_results.contains_result_code?(added_code)).to be true
      expect(audit_results.contains_result_code?(other_code)).to be false
    end
  end

  describe 'result array subsets' do
    let(:result_code) { AuditResults::CM_STATUS_CHANGED }
    let(:error_status_hash) { { old_status: 'invalid_checksum', new_status: 'invalid_moab' } }
    let(:completed_status_hash) { { old_status: 'invalid_checksum', new_status: 'ok' } }

    before do
      audit_results.add_result(result_code, completed_status_hash)
      audit_results.add_result(result_code, error_status_hash)
    end

    describe '#error_results' do
      it 'returns only error results' do
        expect(audit_results.error_results.count).to eq(1)
        expect(audit_results.error_results).to include(
          result_code => format(AuditResults::RESPONSE_CODE_TO_MESSAGES[result_code], error_status_hash)
        )
      end
    end

    describe '#completed_results' do
      it 'returns only non-error results' do
        expect(audit_results.completed_results.count).to eq(1)
        expect(audit_results.completed_results).to include(
          result_code => format(AuditResults::RESPONSE_CODE_TO_MESSAGES[result_code], completed_status_hash)
        )
      end
    end
  end

  describe '#status_changed_to_ok?' do
    it 'returns true if the new status is ok' do
      added_code = AuditResults::CM_STATUS_CHANGED
      audit_results.add_result(added_code, old_status: 'invalid_checksum', new_status: 'ok')
      expect(audit_results.send(:status_changed_to_ok?, audit_results.results.first)).to be true
    end

    it 'returns false if the new status is not ok' do
      added_code = AuditResults::CM_STATUS_CHANGED
      audit_results.add_result(added_code, old_status: 'invalid_checksum', new_status: 'invalid_moab')
      expect(audit_results.send(:status_changed_to_ok?, audit_results.results.first)).to be false
    end
  end

  describe '#to_json' do
    it 'returns valid JSON for the current results' do
      audit_results.add_result(AuditResults::CM_PO_VERSION_MISMATCH, cm_version: 1, po_version: 2)
      json_text = audit_results.to_json
      json_parsed = JSON.parse(json_text)

      exp_msg = 'CompleteMoab online Moab version 1 does not match PreservedObject current_version 2'
      expect(json_parsed.length).to eq 2
      expect(json_parsed['results'].first.length).to eq 1
      expect(json_parsed['results'].first.keys).to eq [AuditResults::CM_PO_VERSION_MISMATCH.to_s]
      expect(json_parsed['results'].first[AuditResults::CM_PO_VERSION_MISMATCH.to_s]).to eq exp_msg
      expect(json_parsed['druid']).to eq druid
    end
  end
end
