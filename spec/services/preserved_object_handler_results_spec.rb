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
    it 'sets result_array to []' do
      expect(pohr.result_array).to eq []
    end
  end

  context '#log_results' do
    before do
      code = PreservedObjectHandlerResults::PC_PO_VERSION_MISMATCH
      addl_hash = { pc_version: 1, po_version: 2 }
      pohr.add_result(code, addl_hash)
    end
    context 'writes to Rails log' do
      it 'with msg_prefix' do
        expect(Rails.logger).to receive(:log).with(Logger::ERROR, a_string_matching(Regexp.escape(pohr.msg_prefix)))
        pohr.log_results
      end
      it 'for each result' do
        code = PreservedObjectHandlerResults::PC_STATUS_CHANGED
        status_details = { old_status: PreservedCopy::INVALID_MOAB_STATUS, new_status: PreservedCopy::OK_STATUS }
        pohr.add_result(code, status_details)
        code = PreservedObjectHandlerResults::UPDATED_DB_OBJECT
        db_obj_details = 'PreservedCopy'
        pohr.add_result(code, db_obj_details)
        not_matched_str = 'does not match PreservedObject current_version'
        expect(Rails.logger).to receive(:log).with(Logger::ERROR, a_string_matching(not_matched_str))
        expect(Rails.logger).to receive(:log).with(Logger::INFO, a_string_matching(PreservedCopy::INVALID_MOAB_STATUS))
        expect(Rails.logger).to receive(:log).with(Logger::INFO, a_string_matching(db_obj_details))
        pohr.log_results
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
    it 'needs tests' do
      skip
    end
  end

  context '#result_hash' do
    it 'needs tests' do
      skip
    end
  end
end
