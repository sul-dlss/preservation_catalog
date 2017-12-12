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
      exp = "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size}, #{endpoint})"
      expect(pohr.msg_prefix).to eq exp
    end
    it 'sets result_array to []' do
      expect(pohr.result_array).to eq []
    end
  end
  context '#log_results' do
    it 'needs tests' do
      skip
    end
  end
  context '#add_result' do
    it 'adds a hash entry to the result_array' do
      expect(pohr.result_array.size).to eq 0
      code = PreservedObjectHandlerResults::PC_PO_VERSION_MISMATCH
      pohr.add_result(code)
      expect(pohr.result_array.size).to eq 1
      exp_msg = "#{pohr.msg_prefix} #{PreservedObjectHandlerResults::RESPONSE_CODE_TO_MESSAGES[code]}"
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
