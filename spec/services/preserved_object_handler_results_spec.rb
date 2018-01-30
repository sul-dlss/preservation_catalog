require 'rails_helper'

RSpec.describe PreservedObjectHandlerResults do
  let(:druid) { 'ab123cd4567' }
  let(:incoming_version) { 6 }
  let(:incoming_size) { 666 }
  let(:endpoint) { Endpoint.find_by(storage_location: 'spec/fixtures/storage_root01/moab_storage_trunk') }
  let(:pohr) { described_class.new(druid, incoming_version, incoming_size, endpoint) }

  context '.logger_severity_level' do
    it 'PC_PO_VERSION_MISMATCH is an ERROR' do
      code = PreservedObjectHandlerResults::PC_PO_VERSION_MISMATCH
      expect(described_class.logger_severity_level(code)).to eq Logger::ERROR
    end
  end

  context '#new' do
    it 'assigns msg_prefix' do
      exp = "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size}, #{endpoint.endpoint_name})"
      expect(pohr.msg_prefix).to eq exp
    end
    it 'sets result_array attr to []' do
      expect(pohr.result_array).to eq []
    end
    it 'sets druid attr to arg' do
      expect(pohr.druid).to eq druid
    end
    it 'sets incoming_version attr to arg' do
      expect(pohr.incoming_version).to eq incoming_version
    end
  end

  context '#report_results' do
    context 'writes to Rails log' do
      before do
        code = PreservedObjectHandlerResults::PC_PO_VERSION_MISMATCH
        addl_hash = { pc_version: 1, po_version: 2 }
        pohr.add_result(code, addl_hash)
      end
      it 'with msg_prefix' do
        expect(Rails.logger).to receive(:log).with(Logger::ERROR, a_string_matching(Regexp.escape(pohr.msg_prefix)))
        pohr.report_results
      end
      it 'for each result' do
        code = PreservedObjectHandlerResults::PC_STATUS_CHANGED
        status_details = { old_status: PreservedCopy::INVALID_MOAB_STATUS, new_status: PreservedCopy::OK_STATUS }
        pohr.add_result(code, status_details)
        not_matched_str = 'does not match PreservedObject current_version'
        expect(Rails.logger).to receive(:log).with(Logger::ERROR, a_string_matching(not_matched_str))
        expect(Rails.logger).to receive(:log).with(Logger::INFO, a_string_matching(PreservedCopy::INVALID_MOAB_STATUS))
        pohr.report_results
      end
    end
    context 'sends errors to workflows' do
      it 'INVALID_MOAB reported with details about the failures' do
        result_code = PreservedObjectHandlerResults::INVALID_MOAB
        moab_valid_errs = [
          "Version directory name not in 'v00xx' format: original-v1",
          "Version v0005: No files present in manifest dir"
        ]
        pohr.add_result(result_code, moab_valid_errs)
        wf_err_msg = pohr.send(:result_code_msg, result_code, moab_valid_errs)
        expect(WorkflowErrorsReporter).to receive(:update_workflow).with(druid, 'moab-valid', wf_err_msg)
        pohr.report_results
      end
      it "does not send results that aren't in WORKFLOW_REPORT_CODES" do
        code = PreservedObjectHandlerResults::CREATED_NEW_OBJECT
        pohr.add_result(code)
        expect(WorkflowErrorsReporter).not_to receive(:update_workflow)
        pohr.report_results
      end
      it 'sends results in WORKFLOW_REPORT_CODES errors' do
        code = PreservedObjectHandlerResults::PC_PO_VERSION_MISMATCH
        addl_hash = { pc_version: 1, po_version: 2 }
        pohr.add_result(code, addl_hash)
        wf_err_msg = pohr.send(:result_code_msg, code, addl_hash)
        expect(WorkflowErrorsReporter).to receive(:update_workflow).with(
          druid, 'preservation-audit', a_string_starting_with(wf_err_msg)
        )
        pohr.report_results
      end
      it 'multiple errors are concatenated together with || separator' do
        code1 = PreservedObjectHandlerResults::PC_PO_VERSION_MISMATCH
        result_msg_args1 = { pc_version: 1, po_version: 2 }
        pohr.add_result(code1, result_msg_args1)
        wf_err_msg1 = pohr.send(:result_code_msg, code1, result_msg_args1)
        code2 = PreservedObjectHandlerResults::OBJECT_ALREADY_EXISTS
        result_msg_args2 = 'foo'
        pohr.add_result(code2, result_msg_args2)
        wf_err_msg2 = pohr.send(:result_code_msg, code2, result_msg_args2)
        expect(WorkflowErrorsReporter).to receive(:update_workflow).with(
          druid, 'preservation-audit', a_string_starting_with("#{wf_err_msg1} || #{wf_err_msg2}")
        )
        pohr.report_results
      end
      it 'includes a truncated stack trace at the end' do
        code = PreservedObjectHandlerResults::PC_PO_VERSION_MISMATCH
        addl_hash = { pc_version: 1, po_version: 2 }
        pohr.add_result(code, addl_hash)
        exp_regex = Regexp.new(" || \
          .*preservation_catalog/app/services/preserved_object_handler_results.rb \
          .*preservation_catalog/spec/services/preserved_object_handler_results_spec.rb .*in <top (required)>")
        expect(WorkflowErrorsReporter).to receive(:update_workflow).with(
          druid, 'preservation-audit', a_string_ending_with(exp_regex)
        )
        pohr.report_results
      end
    end
  end

  context '#add_result' do
    it 'adds a hash entry to the result_array' do
      expect(pohr.result_array.size).to eq 0
      code = PreservedObjectHandlerResults::PC_PO_VERSION_MISMATCH
      addl_hash = { pc_version: 1, po_version: 2 }
      pohr.add_result(code, addl_hash)
      expect(pohr.result_array.size).to eq 1
      exp_msg = "#{pohr.msg_prefix} #{PreservedObjectHandlerResults::RESPONSE_CODE_TO_MESSAGES[code] % addl_hash}"
      expect(pohr.result_array.first).to eq code => exp_msg
    end
    it 'can take a single result code argument' do
      # see above
    end
    it 'can take a second msg_args argument' do
      code = PreservedObjectHandlerResults::VERSION_MATCHES
      pohr.add_result(code, 'foo')
      expect(pohr.result_array.size).to eq 1
      expect(pohr.result_array.first).to eq code => "#{pohr.msg_prefix} incoming version (6) matches foo db version"
    end
  end

  context '#remove_db_updated_results' do
    before do
      code = PreservedObjectHandlerResults::PC_PO_VERSION_MISMATCH
      result_msg_args = { pc_version: 1, po_version: 2 }
      pohr.add_result(code, result_msg_args)
      code = PreservedObjectHandlerResults::PC_STATUS_CHANGED
      result_msg_args = { old_status: PreservedCopy::OK_STATUS, new_status: PreservedCopy::INVALID_MOAB_STATUS }
      pohr.add_result(code, result_msg_args)
      code = PreservedObjectHandlerResults::CREATED_NEW_OBJECT
      pohr.add_result(code)
      code = PreservedObjectHandlerResults::INVALID_MOAB
      pohr.add_result(code, 'foo')
    end
    it 'removes results matching DB_UPDATED_CODES' do
      expect(pohr.result_array.size).to eq 4
      pohr.remove_db_updated_results
      expect(pohr.result_array.size).to eq 2
      expect(pohr.result_array).not_to include(a_hash_including(PreservedObjectHandlerResults::CREATED_NEW_OBJECT))
      expect(pohr.result_array).not_to include(a_hash_including(PreservedObjectHandlerResults::PC_STATUS_CHANGED))
    end
    it 'keeps results not matching DB_UPDATED_CODES' do
      pohr.remove_db_updated_results
      expect(pohr.result_array).to include(a_hash_including(PreservedObjectHandlerResults::PC_PO_VERSION_MISMATCH))
      expect(pohr.result_array).to include(a_hash_including(PreservedObjectHandlerResults::INVALID_MOAB))
    end
  end
end
