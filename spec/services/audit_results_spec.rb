require 'rails_helper'

RSpec.describe AuditResults do
  let(:druid) { 'ab123cd4567' }
  let(:actual_version) { 6 }
  let(:endpoint) { Endpoint.find_by(storage_location: 'spec/fixtures/storage_root01/moab_storage_trunk') }
  let(:audit_results) { described_class.new(druid, actual_version, endpoint) }

  context '.logger_severity_level' do
    it 'PC_PO_VERSION_MISMATCH is an ERROR' do
      code = AuditResults::PC_PO_VERSION_MISMATCH
      expect(described_class.logger_severity_level(code)).to eq Logger::ERROR
    end
  end

  context '#new' do
    it 'assigns msg_prefix' do
      exp = "PreservedObjectHandler(#{druid}, #{actual_version}, #{endpoint.endpoint_name})"
      expect(audit_results.msg_prefix).to eq exp
    end
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

  context '#report_results' do
    context 'writes to Rails log' do
      let(:version_not_matched_str) { 'does not match PreservedObject current_version' }
      let(:result_code) { AuditResults::PC_PO_VERSION_MISMATCH }

      before do
        addl_hash = { pc_version: 1, po_version: 2 }
        audit_results.add_result(result_code, addl_hash)
      end
      it 'with msg_prefix' do
        expect(Rails.logger).to receive(:log).with(Logger::ERROR, a_string_matching(Regexp.escape(audit_results.msg_prefix)))
        audit_results.report_results
      end
      it 'with severity assigned by .logger_severity_level' do
        expect(described_class).to receive(:logger_severity_level).with(result_code).and_return(Logger::FATAL)
        expect(Rails.logger).to receive(:log).with(Logger::FATAL, a_string_matching(version_not_matched_str))
        audit_results.report_results
      end
      it 'for every result' do
        result_code2 = AuditResults::PC_STATUS_CHANGED
        status_details = { old_status: PreservedCopy::INVALID_MOAB_STATUS, new_status: PreservedCopy::OK_STATUS }
        audit_results.add_result(result_code2, status_details)
        severity_level = described_class.logger_severity_level(result_code)
        expect(Rails.logger).to receive(:log).with(severity_level, a_string_matching(version_not_matched_str))
        severity_level = described_class.logger_severity_level(result_code2)
        status_changed_str = "PreservedCopy status changed from #{PreservedCopy::INVALID_MOAB_STATUS}"
        expect(Rails.logger).to receive(:log).with(severity_level, a_string_matching(status_changed_str))
        audit_results.report_results
      end
    end

    context 'sends errors to workflows' do
      it 'INVALID_MOAB reported with details about the failures' do
        result_code = AuditResults::INVALID_MOAB
        moab_valid_errs = [
          "Version directory name not in 'v00xx' format: original-v1",
          "Version v0005: No files present in manifest dir"
        ]
        audit_results.add_result(result_code, moab_valid_errs)
        wf_err_msg = audit_results.send(:result_code_msg, result_code, moab_valid_errs)
        expect(WorkflowErrorsReporter).to receive(:update_workflow).with(druid, 'moab-valid', wf_err_msg)
        audit_results.report_results
      end
      it "does not send results that aren't in WORKFLOW_REPORT_CODES" do
        code = AuditResults::CREATED_NEW_OBJECT
        audit_results.add_result(code)
        expect(WorkflowErrorsReporter).not_to receive(:update_workflow)
        audit_results.report_results
      end
      it 'sends results in WORKFLOW_REPORT_CODES errors' do
        code = AuditResults::PC_PO_VERSION_MISMATCH
        addl_hash = { pc_version: 1, po_version: 2 }
        audit_results.add_result(code, addl_hash)
        wf_err_msg = audit_results.send(:result_code_msg, code, addl_hash)
        expect(WorkflowErrorsReporter).to receive(:update_workflow).with(
          druid, 'preservation-audit', a_string_starting_with(wf_err_msg)
        )
        audit_results.report_results
      end
      it 'multiple errors are concatenated together with || separator' do
        code1 = AuditResults::PC_PO_VERSION_MISMATCH
        result_msg_args1 = { pc_version: 1, po_version: 2 }
        audit_results.add_result(code1, result_msg_args1)
        wf_err_msg1 = audit_results.send(:result_code_msg, code1, result_msg_args1)
        code2 = AuditResults::OBJECT_ALREADY_EXISTS
        result_msg_args2 = 'foo'
        audit_results.add_result(code2, result_msg_args2)
        wf_err_msg2 = audit_results.send(:result_code_msg, code2, result_msg_args2)
        expect(WorkflowErrorsReporter).to receive(:update_workflow).with(
          druid, 'preservation-audit', a_string_starting_with("#{wf_err_msg1} || #{wf_err_msg2}")
        )
        audit_results.report_results
      end
      it 'includes a truncated stack trace at the end' do
        code = AuditResults::PC_PO_VERSION_MISMATCH
        addl_hash = { pc_version: 1, po_version: 2 }
        audit_results.add_result(code, addl_hash)
        exp_regex = Regexp.new(" || \
          .*preservation_catalog/app/services/audit_results.rb \
          .*preservation_catalog/spec/services/audit_results_spec.rb .*in <top (required)>")
        expect(WorkflowErrorsReporter).to receive(:update_workflow).with(
          druid, 'preservation-audit', a_string_ending_with(exp_regex)
        )
        audit_results.report_results
      end
    end
  end

  context '#add_result' do
    it 'adds a hash entry to the result_array' do
      expect(audit_results.result_array.size).to eq 0
      code = AuditResults::PC_PO_VERSION_MISMATCH
      addl_hash = { pc_version: 1, po_version: 2 }
      audit_results.add_result(code, addl_hash)
      expect(audit_results.result_array.size).to eq 1
      exp_msg = "#{audit_results.msg_prefix} #{AuditResults::RESPONSE_CODE_TO_MESSAGES[code] % addl_hash}"
      expect(audit_results.result_array.first).to eq code => exp_msg
    end
    it 'can take a single result code argument' do
      # see above
    end
    it 'can take a second msg_args argument' do
      code = AuditResults::VERSION_MATCHES
      audit_results.add_result(code, 'foo')
      expect(audit_results.result_array.size).to eq 1
      expect(audit_results.result_array.first).to eq code => "#{audit_results.msg_prefix} actual version (6) matches foo db version"
    end
  end

  context '#remove_db_updated_results' do
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
end
