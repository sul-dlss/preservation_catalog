require 'rails_helper'

RSpec.describe AuditResults do
  before do
    allow(Dor::WorkflowService).to receive(:update_workflow_error_status)
    allow(Dor::WorkflowService).to receive(:update_workflow_status)
  end

  let(:druid) { 'ab123cd4567' }
  let(:actual_version) { 6 }
  let(:endpoint) { Endpoint.find_by(storage_location: 'spec/fixtures/storage_root01/sdr2objects') }
  let(:audit_results) { described_class.new(druid, actual_version, endpoint) }

  describe '.logger_severity_level' do
    it 'PC_PO_VERSION_MISMATCH is an ERROR' do
      expect(described_class.logger_severity_level(AuditResults::PC_PO_VERSION_MISMATCH)).to eq Logger::ERROR
    end
    it 'DB_OBJ_DOES_NOT_EXIST is WARN' do
      expect(described_class.logger_severity_level(AuditResults::DB_OBJ_DOES_NOT_EXIST)).to eq Logger::WARN
    end
    it 'CREATED_NEW_OBJECT is INFO' do
      expect(described_class.logger_severity_level(AuditResults::CREATED_NEW_OBJECT)).to eq Logger::INFO
    end
    it 'default for unrecognized value is ERROR' do
      expect(described_class.logger_severity_level(:whatever)).to eq Logger::ERROR
    end
  end

  describe '#new' do
    it 'sets result_array attr to []' do
      expect(audit_results.result_array).to eq []
    end
    it 'sets druid attr to arg' do
      expect(audit_results.druid).to eq druid
    end
    it 'sets actual_version attr to arg' do
      expect(audit_results.actual_version).to eq actual_version
    end
  end

  describe '#report_results' do
    let(:check_name) { 'FooCheck' }

    context 'writes to Rails log' do
      let(:version_not_matched_str) { 'does not match PreservedObject current_version' }
      let(:result_code) { AuditResults::PC_PO_VERSION_MISMATCH }

      before do
        audit_results.check_name = check_name
        addl_hash = { pc_version: 1, po_version: 2 }
        audit_results.add_result(result_code, addl_hash)
      end
      it 'with log_msg_prefix' do
        expected = "FooCheck(#{druid}, fixture_sr1)"
        expect(Rails.logger).to receive(:add).with(Logger::ERROR, a_string_matching(Regexp.escape(expected)))
        audit_results.report_results
      end
      it 'with check name' do
        expect(Rails.logger).to receive(:add).with(Logger::ERROR, a_string_matching(check_name))
        audit_results.report_results
      end
      it 'with druid' do
        expect(Rails.logger).to receive(:add).with(Logger::ERROR, a_string_matching(druid))
        audit_results.report_results
      end
      it 'with endpoint name' do
        expect(Rails.logger).to receive(:add).with(Logger::ERROR, a_string_matching(endpoint.endpoint_name))
        audit_results.report_results
      end
      it 'with severity assigned by .logger_severity_level' do
        expect(described_class).to receive(:logger_severity_level).with(result_code).and_return(Logger::FATAL)
        expect(Rails.logger).to receive(:add).with(Logger::FATAL, a_string_matching(version_not_matched_str))
        audit_results.report_results
      end
      it 'for every result' do
        result_code2 = AuditResults::PC_STATUS_CHANGED
        status_details = { old_status: PreservedCopy::INVALID_MOAB_STATUS, new_status: PreservedCopy::OK_STATUS }
        audit_results.add_result(result_code2, status_details)
        severity_level = described_class.logger_severity_level(result_code)
        expect(Rails.logger).to receive(:add).with(severity_level, a_string_matching(version_not_matched_str))
        severity_level = described_class.logger_severity_level(result_code2)
        status_changed_str = "PreservedCopy status changed from #{PreservedCopy::INVALID_MOAB_STATUS}"
        expect(Rails.logger).to receive(:add).with(severity_level, a_string_matching(status_changed_str))
        audit_results.report_results
      end
      it 'actual_version number is in log message when set after initialization' do
        my_results = described_class.new(druid, nil, endpoint)
        result_code = AuditResults::VERSION_MATCHES
        my_results.actual_version = 666 # NOTE: must be set before "add_result" call
        my_results.add_result(result_code, 'foo')
        expect(Rails.logger).to receive(:add).with(anything, a_string_matching('666'))
        my_results.report_results
      end
    end

    context 'sends errors to workflows' do
      context 'for INVALID_MOAB with' do
        let(:result_code) { AuditResults::INVALID_MOAB }
        let(:moab_valid_errs) {
          [
            "Version directory name not in 'v00xx' format: original-v1",
            "Version v0005: No files present in manifest dir"
          ]
        }
        let(:im_audit_results) {
          ar = described_class.new(druid, actual_version, endpoint)
          ar.check_name = check_name
          ar.add_result(result_code, moab_valid_errs)
          ar
        }

        it 'details about the failures' do
          err_details = im_audit_results.send(:result_code_msg, result_code, moab_valid_errs)
          expect(WorkflowReporter).to receive(:report_error).with(druid, 'moab-valid', a_string_matching(Regexp.escape(err_details)))
          im_audit_results.report_results
        end
        it 'check name' do
          expect(WorkflowReporter).to receive(:report_error).with(druid, 'moab-valid', a_string_matching(check_name))
          im_audit_results.report_results
        end
        it 'endpoint name' do
          expected = Regexp.escape("actual location: #{endpoint.endpoint_name}")
          expect(WorkflowReporter).to receive(:report_error).with(druid, 'moab-valid', a_string_matching(expected))
          im_audit_results.report_results
        end
      end
      it "does not send results that aren't in WORKFLOW_REPORT_CODES" do
        code = AuditResults::CREATED_NEW_OBJECT
        audit_results.add_result(code)
        expect(WorkflowReporter).not_to receive(:report_error)
        audit_results.report_results
      end
      it 'sends results in WORKFLOW_REPORT_CODES errors' do
        code = AuditResults::PC_PO_VERSION_MISMATCH
        addl_hash = { pc_version: 1, po_version: 2 }
        audit_results.add_result(code, addl_hash)
        wf_err_msg = audit_results.send(:result_code_msg, code, addl_hash)
        expect(WorkflowReporter).to receive(:report_error).with(
          druid, 'preservation-audit', a_string_matching(wf_err_msg)
        )
        audit_results.report_results
      end
      it 'multiple errors are concatenated together with || separator' do
        code1 = AuditResults::PC_PO_VERSION_MISMATCH
        result_msg_args1 = { pc_version: 1, po_version: 2 }
        audit_results.add_result(code1, result_msg_args1)
        result_msg1 = audit_results.send(:result_code_msg, code1, result_msg_args1)
        code2 = AuditResults::DB_OBJ_ALREADY_EXISTS
        result_msg_args2 = 'foo'
        audit_results.add_result(code2, result_msg_args2)
        result_msg2 = audit_results.send(:result_code_msg, code2, result_msg_args2)
        allow(WorkflowReporter).to receive(:report_error).with(
          druid, 'preservation-audit', instance_of(String)
        )
        audit_results.report_results
        expect(WorkflowReporter).to have_received(:report_error).with(
          druid, 'preservation-audit', a_string_matching(result_msg1)
        )
        expect(WorkflowReporter).to have_received(:report_error).with(
          druid, 'preservation-audit', a_string_matching(/ \&\& /)
        )
        expect(WorkflowReporter).to have_received(:report_error).with(
          druid, 'preservation-audit', a_string_matching(result_msg2)
        )
      end
      it 'message sent includes endpoint information' do
        code = AuditResults::DB_UPDATE_FAILED
        audit_results.add_result(code)
        expected = Regexp.escape("actual location: #{endpoint.endpoint_name}")
        expect(WorkflowReporter).to receive(:report_error).with(
          druid, 'preservation-audit', a_string_matching(expected)
        )
        audit_results.report_results
      end
      it 'does NOT send endpoint information if there is none' do
        audit_results = described_class.new(druid, actual_version, nil)
        code = AuditResults::DB_UPDATE_FAILED
        audit_results.add_result(code)
        unexpected = Regexp.escape("actual location: ")
        expect(WorkflowReporter).not_to receive(:report_error).with(
          druid, 'preservation-audit', a_string_matching(unexpected)
        )
        expect(WorkflowReporter).to receive(:report_error).with(druid, 'preservation-audit', anything)
        audit_results.report_results
      end
      it 'message sent includes actual version of object' do
        code = AuditResults::DB_UPDATE_FAILED
        audit_results.add_result(code)
        expected = "actual version: #{actual_version}"
        expect(WorkflowReporter).to receive(:report_error).with(
          druid, 'preservation-audit', a_string_matching(expected)
        )
        audit_results.report_results
      end
      it 'does NOT send actual version if there is none' do
        audit_results = described_class.new(druid, nil, endpoint)
        code = AuditResults::DB_UPDATE_FAILED
        audit_results.add_result(code)
        unexpected = Regexp.escape("actual version: ")
        expect(WorkflowReporter).not_to receive(:report_error).with(
          druid, 'preservation-audit', a_string_matching(unexpected)
        )
        expect(WorkflowReporter).to receive(:report_error).with(druid, 'preservation-audit', anything)
        audit_results.report_results
      end
      context 'MOAB_NOT_FOUND result' do
        let(:result_code) { AuditResults::MOAB_NOT_FOUND }
        let(:create_date) { (Time.current - 5.days).utc.iso8601 }
        let(:update_date) { Time.current.utc.iso8601 }
        let(:addl) { { db_created_at: create_date, db_updated_at: update_date } }
        let(:my_audit_results) {
          ar = described_class.new(druid, actual_version, endpoint)
          ar.add_result(result_code, addl)
          ar
        }

        it 'message sent includes PreservedCopy create date' do
          expected = Regexp.escape("db PreservedCopy (created #{create_date}")
          expect(WorkflowReporter).to receive(:report_error).with(
            druid, 'preservation-audit', a_string_matching(expected)
          )
          my_audit_results.report_results
        end
        it 'message sent includes PreservedCopy updated date' do
          expected = "db PreservedCopy .* last updated #{update_date}"
          expect(WorkflowReporter).to receive(:report_error).with(
            druid, 'preservation-audit', a_string_matching(expected)
          )
          my_audit_results.report_results
        end
      end
    end

    context 'resets workflow error' do
      it 'has AuditResult:PC_STATUS_CHANGED and PreseredCopy::OK_STATUS' do
        result_code = AuditResults::PC_STATUS_CHANGED
        addl_hash = { old_status: 'invalid_checksum', new_status: 'ok' }
        audit_results.add_result(result_code, addl_hash)
        expect(WorkflowReporter).to receive(:report_completed).with(druid, 'preservation-audit')
        audit_results.report_results
      end
    end
  end

  describe '#add_result' do
    it 'adds a hash entry to the result_array' do
      expect(audit_results.result_array.size).to eq 0
      code = AuditResults::PC_PO_VERSION_MISMATCH
      addl_hash = { pc_version: 1, po_version: 2 }
      audit_results.add_result(code, addl_hash)
      expect(audit_results.result_array.size).to eq 1
      exp_msg = AuditResults::RESPONSE_CODE_TO_MESSAGES[code] % addl_hash
      expect(audit_results.result_array.first).to eq code => exp_msg
    end
    it 'can take a single result code argument' do
      # see above
    end
    it 'can take a second msg_args argument' do
      code = AuditResults::VERSION_MATCHES
      audit_results.add_result(code, 'foo')
      expect(audit_results.result_array.size).to eq 1
      expect(audit_results.result_array.first).to eq code => "actual version (6) matches foo db version"
    end
  end

  describe '#remove_db_updated_results' do
    before do
      code = AuditResults::PC_PO_VERSION_MISMATCH
      result_msg_args = { pc_version: 1, po_version: 2 }
      audit_results.add_result(code, result_msg_args)
      code = AuditResults::PC_STATUS_CHANGED
      result_msg_args = { old_status: PreservedCopy::OK_STATUS, new_status: PreservedCopy::INVALID_MOAB_STATUS }
      audit_results.add_result(code, result_msg_args)
      code = AuditResults::CREATED_NEW_OBJECT
      audit_results.add_result(code)
      code = AuditResults::INVALID_MOAB
      audit_results.add_result(code, 'foo')
    end
    it 'removes results matching DB_UPDATED_CODES' do
      expect(audit_results.result_array.size).to eq 4
      audit_results.remove_db_updated_results
      expect(audit_results.result_array.size).to eq 2
      audit_results.result_array.each do |result_hash|
        expect(AuditResults::DB_UPDATED_CODES).not_to include(result_hash.keys.first)
      end
      expect(audit_results.result_array).not_to include(a_hash_including(AuditResults::CREATED_NEW_OBJECT))
      expect(audit_results.result_array).not_to include(a_hash_including(AuditResults::PC_STATUS_CHANGED))
    end
    it 'keeps results not matching DB_UPDATED_CODES' do
      audit_results.remove_db_updated_results
      expect(audit_results.result_array).to include(a_hash_including(AuditResults::PC_PO_VERSION_MISMATCH))
      expect(audit_results.result_array).to include(a_hash_including(AuditResults::INVALID_MOAB))
    end
  end

  describe '#contains_result_code?' do
    it 'returns true if the result code is there, false if not' do
      expect(audit_results.result_array.size).to eq 0
      added_code = AuditResults::PC_PO_VERSION_MISMATCH
      other_code = AuditResults::VERSION_MATCHES
      audit_results.add_result(added_code, pc_version: 1, po_version: 2)
      expect(audit_results.contains_result_code?(added_code)).to eq true
      expect(audit_results.contains_result_code?(other_code)).to eq false
    end
  end

  describe '#status_changed_to_ok?' do
    it 'returns true if the new status is ok' do
      added_code = AuditResults::PC_STATUS_CHANGED
      audit_results.add_result(added_code, old_status: 'invalid_checksum', new_status: 'ok')
      expect(audit_results.status_changed_to_ok?(audit_results.result_array.first)).to eq true
    end
    it 'returns false if the new status is not ok' do
      added_code = AuditResults::PC_STATUS_CHANGED
      audit_results.add_result(added_code, old_status: 'invalid_checksum', new_status: 'invalid_moab')
      expect(audit_results.status_changed_to_ok?(audit_results.result_array.first)).to eq false
    end
  end

  describe '#to_json' do
    it 'returns valid JSON for the current result_array' do
      audit_results.add_result(AuditResults::PC_PO_VERSION_MISMATCH, pc_version: 1, po_version: 2)
      json_text = audit_results.to_json
      json_parsed = JSON.parse(json_text)

      exp_msg = "PreservedCopy online Moab version 1 does not match PreservedObject current_version 2"
      expect(json_parsed.length).to eq 2
      expect(json_parsed["result_array"].first.length).to eq 1
      expect(json_parsed["result_array"].first.keys).to eq [AuditResults::PC_PO_VERSION_MISMATCH.to_s]
      expect(json_parsed["result_array"].first[AuditResults::PC_PO_VERSION_MISMATCH.to_s]).to eq exp_msg
      expect(json_parsed["druid"]).to eq druid
    end
  end
end
