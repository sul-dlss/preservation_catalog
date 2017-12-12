RSpec.shared_examples "attributes validated" do |method_sym|
  let(:bad_druid) { '666' }
  let(:bad_version) { 'vv666' }
  let(:bad_size) { '-666' }
  let(:bad_endpoint) { nil }
  let(:bad_druid_msg) { 'Druid is invalid' }
  let(:bad_version_msg) { 'Incoming version is not a number' }
  let(:bad_size_msg) { 'Incoming size must be greater than 0' }
  let(:bad_endpoint_msg) { "Endpoint must be an actual Endpoint" }

  context 'returns' do
    let!(:result) do
      po_handler = described_class.new(bad_druid, bad_version, bad_size, bad_endpoint)
      po_handler.send(method_sym)
    end

    it '1 result' do
      expect(result).to be_an_instance_of Array
      expect(result.size).to eq 1
    end
    it 'INVALID_ARGUMENTS' do
      expect(result).to include(a_hash_including(PreservedObjectHandlerResults::INVALID_ARGUMENTS))
    end
    context 'result message includes' do
      let(:msg) { result.first[PreservedObjectHandlerResults::INVALID_ARGUMENTS] }
      let(:exp_msg_prefix) { "PreservedObjectHandler(#{bad_druid}, #{bad_version}, #{bad_size}, #{bad_endpoint})" }

      it "prefix" do
        expect(msg).to match(Regexp.escape("#{exp_msg_prefix} encountered validation error(s): "))
      end
      it "druid error" do
        expect(msg).to match(bad_druid_msg)
      end
      it "version error" do
        expect(msg).to match(bad_version_msg)
      end
      it "size error" do
        expect(msg).to match(bad_size_msg)
      end
      it "endpoint error" do
        expect(msg).to match(bad_endpoint_msg)
      end
    end
  end

  it 'bad druid error is written to Rails log' do
    po_handler = described_class.new(bad_druid, incoming_version, incoming_size, ep)
    err_msg = "PreservedObjectHandler(#{bad_druid}, #{incoming_version}, #{incoming_size}, #{ep}) encountered validation error(s): [\"#{bad_druid_msg}\"]"
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
    po_handler.send(method_sym)
  end
  it 'bad version error is written to Rails log' do
    po_handler = described_class.new(druid, bad_version, incoming_size, ep)
    err_msg = "PreservedObjectHandler(#{druid}, #{bad_version}, #{incoming_size}, #{ep}) encountered validation error(s): [\"#{bad_version_msg}\"]"
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
    po_handler.send(method_sym)
  end
  it 'bad size error is written to Rails log' do
    po_handler = described_class.new(druid, incoming_version, bad_size, ep)
    err_msg = "PreservedObjectHandler(#{druid}, #{incoming_version}, #{bad_size}, #{ep}) encountered validation error(s): [\"#{bad_size_msg}\"]"
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
    po_handler.send(method_sym)
  end
  it 'bad endpoint is written to Rails log' do
    po_handler = described_class.new(druid, incoming_version, incoming_size, bad_endpoint)
    err_msg = "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size}, #{bad_endpoint}) encountered validation error(s): [\"#{bad_endpoint_msg}\"]"
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
    po_handler.send(method_sym)
  end
end

RSpec.shared_examples 'druid not in catalog' do |method_sym|
  let(:druid) { 'rr111rr1111' }
  # let(:exp_msg) { "#{exp_msg_prefix} #<ActiveRecord::RecordNotFound: Couldn't find PreservedObject> db object does not exist" }
  let(:escaped_exp_msg) { Regexp.escape("#{exp_msg_prefix}") + ".* PreservedObject.* db object does not exist" }
  let(:results) do
    allow(Rails.logger).to receive(:log)
    # FIXME: couldn't figure out how to put next line into its own test
    # expect(Rails.logger).to receive(:log).with(Logger::ERROR, /#{Regexp.escape(exp_msg)}/)
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, /#{escaped_exp_msg}/)
    po_handler.send(method_sym)
  end

  it 'OBJECT_DOES_NOT_EXIST error' do
    # exp_msg = Regexp.escape("#{exp_msg_prefix}") + ".* PreservedObject.* db object does not exist"
    code = PreservedObjectHandlerResults::OBJECT_DOES_NOT_EXIST
    expect(results).to include(a_hash_including(code => a_string_matching(escaped_exp_msg)))
  end
end

RSpec.shared_examples 'PreservedCopy does not exist' do |method_sym|
  before do
    PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy)
  end
  let(:exp_msg) { "#{exp_msg_prefix} #<ActiveRecord::RecordNotFound: foo> db object does not exist" }
  let(:results) do
    allow(Rails.logger).to receive(:log)
    # FIXME: couldn't figure out how to put next line into its own test
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, /#{Regexp.escape(exp_msg)}/)
    po = instance_double(PreservedObject)
    allow(po).to receive(:current_version).and_return(2)
    allow(po).to receive(:current_version=)
    allow(po).to receive(:changed?).and_return(true)
    allow(po).to receive(:save!)
    allow(PreservedObject).to receive(:find_by!).and_return(po)
    # allow(PreservedObject).to receive(:find_by!).and_return(instance_double(PreservedObject))
    allow(PreservedCopy).to receive(:find_by!).and_raise(ActiveRecord::RecordNotFound, 'foo')
    po_handler.send(method_sym)
  end

  it 'OBJECT_DOES_NOT_EXIST error' do
    code = PreservedObjectHandlerResults::OBJECT_DOES_NOT_EXIST
    expect(results).to include(a_hash_including(code => exp_msg))
  end
end

RSpec.shared_examples 'unexpected version' do |incoming_version|
  let(:po_handler) { described_class.new(druid, incoming_version, 1, ep) }
  let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, 1, #{ep})" }
  let(:version_msg_prefix) { "#{exp_msg_prefix} incoming version (#{incoming_version})" }
  let(:unexpected_version_msg) { "#{version_msg_prefix} has unexpected relationship to PreservedCopy db version; ERROR!" }
  let(:updated_po_db_timestamp_msg) { "#{exp_msg_prefix} PreservedObject updated db timestamp only" }
  let(:updated_pc_db_timestamp_msg) { "#{exp_msg_prefix} PreservedCopy updated db timestamp only" }
  let(:updated_status_msg_regex) { Regexp.new(Regexp.escape("#{exp_msg_prefix} PreservedCopy status changed from")) }

  it "PreservedCopy version stays the same" do
    pcv = pc.version
    po_handler.update_version
    expect(pc.reload.version).to eq pcv
  end
  it "PreservedObject current_version stays the same" do
    pocv = po.current_version
    po_handler.update_version
    expect(po.reload.current_version).to eq pocv
  end
  it "PreservedCopy size stays the same" do
    expect(pc.size).to eq 1
    po_handler.update_version
    expect(pc.reload.size).to eq 1
  end
  it 'does not update PreservedCopy last_audited field' do
    orig_timestamp = pc.last_audited
    po_handler.update_version
    expect(pc.reload.last_audited).to eq orig_timestamp
  end
  it 'does not update PreservedCopy last_checked_on_storage' do
    orig_timestamp = pc.last_checked_on_storage
    po_handler.update_version
    expect(pc.reload.last_checked_on_storage).to eq orig_timestamp
  end
  it 'does not update status of PreservedCopy' do
    orig_status = pc.status
    po_handler.update_version
    expect(pc.reload.status).to eq orig_status
  end
  it "logs at error level" do
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, unexpected_version_msg)
    expect(Rails.logger).not_to receive(:log).with(Logger::INFO, updated_pc_db_timestamp_msg)
    expect(Rails.logger).not_to receive(:log).with(Logger::ERROR, updated_po_db_timestamp_msg)
    expect(Rails.logger).not_to receive(:log).with(Logger::INFO, updated_status_msg_regex)
    po_handler.update_version
  end

  context 'returns' do
    let!(:results) { po_handler.update_version }

    # results = [result1, result2]
    # result1 = {response_code: msg}
    # result2 = {response_code: msg}
    it '3 results' do
      expect(results).to be_an_instance_of Array
      expect(results.size).to eq 3
    end
    it 'UNEXPECTED_VERSION result' do
      code = PreservedObjectHandlerResults::UNEXPECTED_VERSION
      expect(results).to include(a_hash_including(code => unexpected_version_msg))
    end
    it 'specific version results' do
      # NOTE this is not checking that we have the CORRECT specific code
      codes = [
        PreservedObjectHandlerResults::VERSION_MATCHES,
        PreservedObjectHandlerResults::ARG_VERSION_GREATER_THAN_DB_OBJECT,
        PreservedObjectHandlerResults::ARG_VERSION_LESS_THAN_DB_OBJECT
      ]
      obj_version_results = results.select { |r| codes.include?(r.keys.first) }
      msgs = obj_version_results.map { |r| r.values.first }
      expect(msgs).to include(a_string_matching("PreservedObject"))
      expect(msgs).to include(a_string_matching("PreservedCopy"))
    end
    it "no UPDATED_DB_OBJECT_TIMESTAMP_ONLY results" do
      expect(results).not_to include(a_hash_including(PreservedObjectHandlerResults::UPDATED_DB_OBJECT_TIMESTAMP_ONLY))
    end
    it 'no PC_STATUS_CHANGED result' do
      expect(results).not_to include(a_hash_including(PreservedObjectHandlerResults::PC_STATUS_CHANGED))
    end
  end
end
