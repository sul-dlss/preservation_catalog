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
      let(:exp_msg_prefix) { "PreservedObjectHandler(#{bad_druid}, #{bad_version}, #{bad_size}, #{bad_endpoint.endpoint_name if bad_endpoint})" }

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
    err_msg = "PreservedObjectHandler(#{bad_druid}, #{incoming_version}, #{incoming_size}, #{ep.endpoint_name}) encountered validation error(s): [\"#{bad_druid_msg}\"]"
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
    po_handler.send(method_sym)
  end
  it 'bad version error is written to Rails log' do
    po_handler = described_class.new(druid, bad_version, incoming_size, ep)
    err_msg = "PreservedObjectHandler(#{druid}, #{bad_version}, #{incoming_size}, #{ep.endpoint_name}) encountered validation error(s): [\"#{bad_version_msg}\"]"
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
    po_handler.send(method_sym)
  end
  it 'bad size error is written to Rails log' do
    po_handler = described_class.new(druid, incoming_version, bad_size, ep)
    err_msg = "PreservedObjectHandler(#{druid}, #{incoming_version}, #{bad_size}, #{ep.endpoint_name}) encountered validation error(s): [\"#{bad_size_msg}\"]"
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
    po_handler.send(method_sym)
  end
  it 'bad endpoint is written to Rails log' do
    po_handler = described_class.new(druid, incoming_version, incoming_size, bad_endpoint)
    err_msg = "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size}, ) encountered validation error(s): [\"#{bad_endpoint_msg}\"]"
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, err_msg)
    po_handler.send(method_sym)
  end
end

RSpec.shared_examples 'calls PreservedObjectHandlerResults.report_results' do |method_sym|
  it '' do
    mock_results = instance_double(PreservedObjectHandlerResults)
    allow(mock_results).to receive(:add_result)
    allow(mock_results).to receive(:result_array) # TODO: remove this when switch to report_results call
    expect(mock_results).to receive(:report_results) # TODO: change this when switch to report_results call
    expect(PreservedObjectHandlerResults).to receive(:new).and_return(mock_results)
    po_handler.send(method_sym)
  end
end

RSpec.shared_examples 'druid not in catalog' do |method_sym|
  let(:druid) { 'rr111rr1111' }
  let(:escaped_exp_msg) { Regexp.escape(exp_msg_prefix) + ".* PreservedObject.* db object does not exist" }
  let(:results) do
    allow(Rails.logger).to receive(:log)
    # FIXME: couldn't figure out how to put next line into its own test
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, /#{escaped_exp_msg}/)
    po_handler.send(method_sym)
  end

  it 'OBJECT_DOES_NOT_EXIST error' do
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
    allow(PreservedCopy).to receive(:find_by!).and_raise(ActiveRecord::RecordNotFound, 'foo')
    po_handler.send(method_sym)
  end

  it 'OBJECT_DOES_NOT_EXIST error' do
    code = PreservedObjectHandlerResults::OBJECT_DOES_NOT_EXIST
    expect(results).to include(a_hash_including(code => exp_msg))
  end
end

RSpec.shared_examples 'unexpected version' do |method_sym, incoming_version|
  let(:po_handler) { described_class.new(druid, incoming_version, 1, ep) }
  let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, 1, #{ep.endpoint_name if ep})" }
  let(:version_msg_prefix) { "#{exp_msg_prefix} incoming version (#{incoming_version})" }
  let(:unexpected_version_msg) { "#{version_msg_prefix} has unexpected relationship to PreservedCopy db version; ERROR!" }
  let(:updated_po_db_timestamp_msg) { "#{exp_msg_prefix} PreservedObject updated db timestamp only" }
  let(:updated_pc_db_timestamp_msg) { "#{exp_msg_prefix} PreservedCopy updated db timestamp only" }
  let(:updated_status_msg_regex) { Regexp.new(Regexp.escape("#{exp_msg_prefix} PreservedCopy status changed from")) }

  context 'PreservedCopy' do
    context 'changed' do
      it 'last_version_audit' do
        orig = pc.last_version_audit
        po_handler.send(method_sym)
        expect(pc.reload.last_version_audit).to be > orig
      end
      if method_sym == :update_version
        it 'status becomes EXPECTED_VERS_NOT_FOUND_ON_STORAGE_STATUS' do
          orig = pc.status
          po_handler.send(method_sym)
          expect(pc.reload.status).to eq PreservedCopy::EXPECTED_VERS_NOT_FOUND_ON_STORAGE_STATUS
          expect(pc.status).not_to eq orig
        end
      end
    end
    context 'unchanged' do
      it "version" do
        orig = pc.version
        po_handler.send(method_sym)
        expect(pc.reload.version).to eq orig
      end
      it "size" do
        orig = pc.size
        po_handler.send(method_sym)
        expect(pc.reload.size).to eq orig
      end
      it 'last_moab_validation' do
        orig = pc.last_moab_validation
        po_handler.send(method_sym)
        expect(pc.reload.last_moab_validation).to eq orig
      end
      if method_sym != :update_version
        it 'status becomes EXPECTED_VERS_NOT_FOUND_ON_STORAGE_STATUS' do
          orig = pc.status
          po_handler.send(method_sym)
          expect(pc.status).to eq orig
        end
      end
    end
  end
  context 'PreservedObject' do
    context 'unchanged' do
      it "PreservedObject current_version stays the same" do
        pocv = po.current_version
        po_handler.send(method_sym)
        expect(po.reload.current_version).to eq pocv
      end
    end
  end

  it "logs at error level" do
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, unexpected_version_msg)
    expect(Rails.logger).not_to receive(:log).with(Logger::INFO, updated_pc_db_timestamp_msg)
    expect(Rails.logger).not_to receive(:log).with(Logger::ERROR, updated_po_db_timestamp_msg)
    allow(Rails.logger).to receive(:log).with(Logger::INFO, updated_status_msg_regex)
    po_handler.send(method_sym)
  end

  context 'returns' do
    let!(:results) { po_handler.send(method_sym) }

    # results = [result1, result2]
    # result1 = {response_code: msg}
    # result2 = {response_code: msg}
    it "number of results" do
      expect(results).to be_an_instance_of Array
      expect(results.size).to eq 5
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
    it "UPDATED_DB_OBJECT result for PreservedCopy" do
      expect(results).to include(a_hash_including(PreservedObjectHandlerResults::UPDATED_DB_OBJECT => a_string_matching('PreservedCopy db object updated')))
    end
    if method_sym == :update_version
      it 'PC_STATUS_CHANGED result' do
        expect(results).to include(a_hash_including(PreservedObjectHandlerResults::PC_STATUS_CHANGED))
      end
    else
      it 'no PC_STATUS_CHANGED result' do
        expect(results).not_to include(a_hash_including(PreservedObjectHandlerResults::PC_STATUS_CHANGED))
      end
    end
    it "no UPDATED_DB_OBJECT result for PreservedObject" do
      expect(results).not_to include(a_hash_including(PreservedObjectHandlerResults::UPDATED_DB_OBJECT => a_string_matching('PreservedObject db object updated')))
      expect(results).not_to include(a_hash_including(PreservedObjectHandlerResults::UPDATED_DB_OBJECT_TIMESTAMP_ONLY))
    end
  end
end

RSpec.shared_examples 'unexpected version with validation' do |method_sym, incoming_version, new_status|
  let(:po_handler) { described_class.new(druid, incoming_version, 1, ep) }
  let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, 1, #{ep.endpoint_name if ep})" }
  let(:version_msg_prefix) { "#{exp_msg_prefix} incoming version (#{incoming_version})" }
  let(:unexpected_version_msg) { "#{version_msg_prefix} has unexpected relationship to PreservedCopy db version; ERROR!" }
  let(:updated_status_msg_regex) { Regexp.new(Regexp.escape("#{exp_msg_prefix} PreservedCopy status changed from")) }
  let(:updated_pc_db_msg) { "#{exp_msg_prefix} PreservedCopy db object updated" }
  let(:updated_po_db_msg) { "#{exp_msg_prefix} PreservedObject db object updated" }

  context 'PreservedCopy' do
    context 'changed' do
      it 'last_moab_validation' do
        orig = Time.current
        pc.last_moab_validation = orig
        pc.save!
        po_handler.send(method_sym)
        expect(pc.reload.last_moab_validation).to be > orig
      end
      if method_sym == :check_existence
        it 'last_version_audit' do
          orig = Time.current
          pc.last_version_audit = orig
          pc.save!
          po_handler.send(method_sym)
          expect(pc.reload.last_version_audit).to be > orig
        end
      end
    end
    context 'unchanged' do
      it "version" do
        pcv = pc.version
        po_handler.send(method_sym)
        expect(pc.reload.version).to eq pcv
      end
      it "size" do
        expect(pc.size).to eq 1
        po_handler.send(method_sym)
        expect(pc.reload.size).to eq 1
      end
      if method_sym == :update_version_after_validation
        it 'last_version_audit' do
          orig = pc.last_version_audit
          po_handler.send(method_sym)
          expect(pc.reload.last_version_audit).to eq orig
        end
      end
    end
  end
  context 'PreservedObject' do
    context 'unchanged' do
      it "current_version" do
        pocv = po.current_version
        po_handler.send(method_sym)
        expect(po.reload.current_version).to eq pocv
      end
    end
  end
  it "ensures status of PreservedCopy is #{new_status}" do
    pc.status = PreservedCopy::OK_STATUS
    pc.save!
    po_handler.send(method_sym)
    expect(pc.reload.status).to eq new_status
  end
  it "logs at error level" do
    allow(Rails.logger).to receive(:log).with(Logger::ERROR, unexpected_version_msg)
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, any_args).at_least(1).times
    expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_msg)
    expect(Rails.logger).not_to receive(:log).with(Logger::ERROR, updated_po_db_msg)
    expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_status_msg_regex)
    po_handler.send(method_sym)
  end

  context 'returns' do
    let!(:results) { po_handler.send(method_sym) }
    let(:num_results) do
      if method_sym == :check_existence
        4
      elsif method_sym == :update_version_after_validation
        3
      end
    end

    # results = [result1, result2]
    # result1 = {response_code: msg}
    # result2 = {response_code: msg}
    it "number of results" do
      expect(results).to be_an_instance_of Array
      expect(results.size).to eq num_results
    end
    if method_sym == :update_version_after_validation
      it 'UNEXPECTED_VERSION result unless INVALID_MOAB' do
        unless results.find { |r| r.keys.first == PreservedObjectHandlerResults::INVALID_MOAB }
          code = PreservedObjectHandlerResults::UNEXPECTED_VERSION
          expect(results).to include(a_hash_including(code => unexpected_version_msg))
        end
      end
    end
    it 'specific version results' do
      codes = [
        PreservedObjectHandlerResults::VERSION_MATCHES,
        PreservedObjectHandlerResults::ARG_VERSION_GREATER_THAN_DB_OBJECT,
        PreservedObjectHandlerResults::ARG_VERSION_LESS_THAN_DB_OBJECT
      ]
      obj_version_results = results.select { |r| codes.include?(r.keys.first) }
      msgs = obj_version_results.map { |r| r.values.first }
      unless results.find { |r| r.keys.first == PreservedObjectHandlerResults::INVALID_MOAB }
        expect(msgs).to include(a_string_matching("PreservedObject"))
        expect(msgs).to include(a_string_matching("PreservedCopy"))
      end
    end
    it "PreservedCopy UPDATED_DB_OBJECT results" do
      code = PreservedObjectHandlerResults::UPDATED_DB_OBJECT
      expect(results).to include(a_hash_including(code => updated_pc_db_msg))
    end
    it 'PC_STATUS_CHANGED result' do
      expect(results).to include(a_hash_including(PreservedObjectHandlerResults::PC_STATUS_CHANGED => updated_status_msg_regex))
    end
  end
end

RSpec.shared_examples 'update for invalid moab' do |method_sym|
  let(:updated_status_msg_regex) { Regexp.new(Regexp.escape("#{exp_msg_prefix} PreservedCopy status changed from")) }
  let(:invalid_moab_msg) { "#{exp_msg_prefix} Invalid moab, validation errors: [\"Missing directory: [\\\"data\\\", \\\"manifests\\\"] Version: v0001\"]" }
  let(:updated_pc_db_msg) { "#{exp_msg_prefix} PreservedCopy db object updated" }
  let(:updated_po_db_msg) { "#{exp_msg_prefix} PreservedObject db object updated" }

  context 'PreservedCopy' do
    context 'changed' do
      it 'last_moab_validation' do
        orig = pc.last_moab_validation
        po_handler.send(method_sym)
        expect(pc.reload.last_moab_validation).to be > orig
      end
      it 'status' do
        orig = pc.status
        po_handler.send(method_sym)
        expect(pc.reload.status).to eq PreservedCopy::INVALID_MOAB_STATUS
        expect(pc.status).not_to eq orig
      end
    end
    context 'unchanged' do
      it 'last_version_audit' do
        orig = pc.last_version_audit
        po_handler.send(method_sym)
        expect(pc.reload.last_version_audit).to eq orig
      end
      it 'size' do
        orig = pc.size
        po_handler.send(method_sym)
        expect(pc.reload.size).to eq orig
      end
      it 'version' do
        orig = pc.version
        po_handler.send(method_sym)
        expect(pc.reload.version).to eq orig
      end
    end
  end
  it 'does not update PreservedObject' do
    orig = po.reload.updated_at
    po_handler.send(method_sym)
    expect(po.reload.updated_at).to eq orig
  end

  it "logs at error level" do
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, invalid_moab_msg)
    expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_msg)
    expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_status_msg_regex)
    po_handler.send(method_sym)
  end

  context 'returns' do
    let!(:results) { po_handler.send(method_sym) }

    # results = [result1, result2]
    # result1 = {response_code: msg}
    # result2 = {response_code: msg}
    it '3 results' do
      expect(results).to be_an_instance_of Array
      expect(results.size).to eq 3
    end
    it 'INVALID_MOAB result' do
      code = PreservedObjectHandlerResults::INVALID_MOAB
      expect(results).to include(hash_including(code => invalid_moab_msg))
    end
    it 'PC_STATUS_CHANGED result' do
      expect(results).to include(a_hash_including(PreservedObjectHandlerResults::PC_STATUS_CHANGED => updated_status_msg_regex))
    end
    it 'UPDATED_DB_OBJECT for PreservedCopy' do
      expect(results).to include(hash_including(PreservedObjectHandlerResults::UPDATED_DB_OBJECT => updated_pc_db_msg))
    end
    it 'does NOT get UPDATED_DB_OBJECT message for PreservedObject' do
      expect(results).not_to include(hash_including(PreservedObjectHandlerResults::UPDATED_DB_OBJECT => updated_po_db_msg))
      expect(results).not_to include(hash_including(PreservedObjectHandlerResults::UPDATED_DB_OBJECT_TIMESTAMP_ONLY))
    end
  end
end

RSpec.shared_examples 'PreservedObject current_version does not match online PC version' do |method_sym, incoming_version, pc_v, po_v|
  let(:po_handler) { described_class.new(druid, incoming_version, 1, ep) }
  let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, 1, #{ep.endpoint_name if ep})" }
  let(:version_mismatch_msg) { "#{exp_msg_prefix} PreservedCopy online moab version #{pc_v} does not match PreservedObject current_version #{po_v}" }

  it 'does not update PreservedCopy' do
    orig = pc.updated_at
    po_handler.send(method_sym)
    expect(pc.reload.updated_at).to eq orig
  end
  it 'does not update PreservedObject' do
    orig = po.reload.updated_at
    po_handler.send(method_sym)
    expect(po.reload.updated_at).to eq orig
  end

  it "logs at error level" do
    expect(Rails.logger).to receive(:log).with(Logger::ERROR, version_mismatch_msg)
    po_handler.send(method_sym)
  end

  context 'returns' do
    let!(:results) { po_handler.send(method_sym) }

    # results = [result1, result2]
    # result1 = {response_code: msg}
    # result2 = {response_code: msg}
    it '1 result' do
      expect(results).to be_an_instance_of Array
      expect(results.size).to eq 1
    end
    it 'PC_PO_VERSION_MISMATCH result' do
      code = PreservedObjectHandlerResults::PC_PO_VERSION_MISMATCH
      expect(results).to include(hash_including(code => version_mismatch_msg))
    end
    it 'does NOT get UPDATED_DB_OBJECT message' do
      expect(results).not_to include(hash_including(PreservedObjectHandlerResults::UPDATED_DB_OBJECT))
      expect(results).not_to include(hash_including(PreservedObjectHandlerResults::UPDATED_DB_OBJECT_TIMESTAMP_ONLY))
    end
  end
end
