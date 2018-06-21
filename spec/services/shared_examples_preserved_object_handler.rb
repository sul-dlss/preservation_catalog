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
      expect(result).to include(a_hash_including(AuditResults::INVALID_ARGUMENTS))
    end
    context 'result message includes' do
      let(:msg) { result.first[AuditResults::INVALID_ARGUMENTS] }

      it "prefix" do
        expect(msg).to match(Regexp.escape("encountered validation error(s): "))
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
end

RSpec.shared_examples 'calls AuditResults.report_results' do |method_sym|
  it 'outputs results to Rails.logger and sends errors to WorkflowErrorReporter' do
    mock_results = instance_double(AuditResults)
    allow(mock_results).to receive(:add_result)
    allow(mock_results).to receive(:check_name=)
    expect(mock_results).to receive(:report_results)
    expect(AuditResults).to receive(:new).and_return(mock_results)
    po_handler.send(method_sym)
  end
end

RSpec.shared_examples 'druid not in catalog' do |method_sym|
  let(:druid) { 'rr111rr1111' }
  let(:exp_msg) { "PreservedObject.* db object does not exist" }
  let(:results) do
    allow(Rails.logger).to receive(:log)
    po_handler.send(method_sym)
  end

  it 'DB_OBJ_DOES_NOT_EXIST error' do
    code = AuditResults::DB_OBJ_DOES_NOT_EXIST
    expect(results).to include(a_hash_including(code => a_string_matching(exp_msg)))
  end
end

RSpec.shared_examples 'PreservedCopy does not exist' do |method_sym|
  before do
    PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy)
  end
  let(:exp_msg) { "#<ActiveRecord::RecordNotFound: foo> db object does not exist" }
  let(:results) do
    allow(Rails.logger).to receive(:log)
    po = instance_double(PreservedObject)
    allow(po).to receive(:current_version).and_return(2)
    allow(po).to receive(:current_version=)
    allow(po).to receive(:changed?).and_return(true)
    allow(po).to receive(:save!)
    allow(PreservedObject).to receive(:find_by!).and_return(po)
    allow(PreservedCopy).to receive(:find_by!).and_raise(ActiveRecord::RecordNotFound, 'foo')
    po_handler.send(method_sym)
  end

  it 'DB_OBJ_DOES_NOT_EXIST error' do
    code = AuditResults::DB_OBJ_DOES_NOT_EXIST
    expect(results).to include(a_hash_including(code => exp_msg))
  end
end

RSpec.shared_examples 'unexpected version' do |method_sym, actual_version|
  let(:po_handler) { described_class.new(druid, actual_version, 1, ep) }
  let(:version_msg_prefix) { "actual version (#{actual_version})" }
  let(:unexpected_version_msg) { "#{version_msg_prefix} has unexpected relationship to PreservedCopy db version (2); ERROR!" }

  context 'PreservedCopy' do
    context 'changed' do
      it 'last_version_audit' do
        orig = pc.last_version_audit
        po_handler.send(method_sym)
        expect(pc.reload.last_version_audit).to be > orig
      end
      if method_sym == :update_version
        it 'status becomes UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
          orig = pc.status
          po_handler.send(method_sym)
          expect(pc.reload.status).to eq PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
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
        it 'status becomes UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
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

  context 'returns' do
    let!(:results) { po_handler.send(method_sym) }

    it "number of results" do
      expect(results).to be_an_instance_of Array
      expect(results.size).to eq 3
    end
    it 'UNEXPECTED_VERSION result' do
      code = AuditResults::UNEXPECTED_VERSION
      expect(results).to include(a_hash_including(code => unexpected_version_msg))
    end
    it 'specific version results' do
      # NOTE this is not checking that we have the CORRECT specific code
      codes = [
        AuditResults::VERSION_MATCHES,
        AuditResults::ACTUAL_VERS_GT_DB_OBJ,
        AuditResults::ACTUAL_VERS_LT_DB_OBJ
      ]
      obj_version_results = results.select { |r| codes.include?(r.keys.first) }
      msgs = obj_version_results.map { |r| r.values.first }
      expect(msgs).to include(a_string_matching("PreservedCopy"))
    end
    if method_sym == :update_version
      it 'PC_STATUS_CHANGED result' do
        expect(results).to include(a_hash_including(AuditResults::PC_STATUS_CHANGED))
      end
    else
      it 'no PC_STATUS_CHANGED result' do
        expect(results).not_to include(a_hash_including(AuditResults::PC_STATUS_CHANGED))
      end
    end
  end
end

RSpec.shared_examples 'unexpected version with validation' do |method_sym, incoming_version, new_status|
  let(:po_handler) { described_class.new(druid, incoming_version, 1, ep) }
  let(:version_msg_prefix) { "actual version (#{incoming_version})" }
  let(:unexpected_version_msg) { "#{version_msg_prefix} has unexpected relationship to PreservedCopy db version; ERROR!" }
  let(:updated_status_msg_regex) { Regexp.new("PreservedCopy status changed from") }

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

  context 'returns' do
    let!(:results) { po_handler.send(method_sym) }

    it "number of results" do
      expect(results).to be_an_instance_of Array
      expect(results.size).to eq 2
    end
    if method_sym == :update_version_after_validation
      it 'UNEXPECTED_VERSION result unless INVALID_MOAB' do
        unless results.find { |r| r.keys.first == AuditResults::INVALID_MOAB }
          code = AuditResults::UNEXPECTED_VERSION
          expect(results).to include(a_hash_including(code => unexpected_version_msg))
        end
      end
    end
    it 'specific version results' do
      codes = [
        AuditResults::VERSION_MATCHES,
        AuditResults::ACTUAL_VERS_GT_DB_OBJ,
        AuditResults::ACTUAL_VERS_LT_DB_OBJ
      ]
      obj_version_results = results.select { |r| codes.include?(r.keys.first) }
      msgs = obj_version_results.map { |r| r.values.first }
      unless results.find { |r| r.keys.first == AuditResults::INVALID_MOAB }
        expect(msgs).to include(a_string_matching("PreservedCopy"))
      end
    end
    it 'PC_STATUS_CHANGED result' do
      expect(results).to include(a_hash_including(AuditResults::PC_STATUS_CHANGED => updated_status_msg_regex))
    end
  end
end

RSpec.shared_examples 'update for invalid moab' do |method_sym|
  let(:updated_status_msg_regex) { Regexp.new("PreservedCopy status changed from") }
  let(:invalid_moab_msg) { "Invalid Moab, validation errors: [\"Missing directory: [\\\"data\\\", \\\"manifests\\\"] Version: v0001\"]" }

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

  context 'returns' do
    let!(:results) { po_handler.send(method_sym) }

    it '3 results' do
      expect(results).to be_an_instance_of Array
      expect(results.size).to eq 2
    end
    it 'INVALID_MOAB result' do
      code = AuditResults::INVALID_MOAB
      expect(results).to include(hash_including(code => invalid_moab_msg))
    end
    it 'PC_STATUS_CHANGED result' do
      expect(results).to include(a_hash_including(AuditResults::PC_STATUS_CHANGED => updated_status_msg_regex))
    end
  end
end

RSpec.shared_examples 'PreservedObject current_version does not match online PC version' do |method_sym, incoming_version, pc_v, po_v|
  let(:po_handler) { described_class.new(druid, incoming_version, 1, ep) }
  let(:version_mismatch_msg) { "PreservedCopy online Moab version #{pc_v} does not match PreservedObject current_version #{po_v}" }

  it 'does not update PreservedCopy' do
    orig = pc.reload.updated_at
    po_handler.send(method_sym)
    expect(pc.reload.updated_at).to eq orig
  end
  it 'does not update PreservedObject' do
    orig = po.reload.updated_at
    po_handler.send(method_sym)
    expect(po.reload.updated_at).to eq orig
  end

  context 'returns' do
    let!(:results) { po_handler.send(method_sym) }

    it '1 result' do
      expect(results).to be_an_instance_of Array
      expect(results.size).to eq 1
    end
    it 'PC_PO_VERSION_MISMATCH result' do
      code = AuditResults::PC_PO_VERSION_MISMATCH
      expect(results).to include(hash_including(code => version_mismatch_msg))
    end
  end
end

RSpec.shared_examples 'cannot validate something with INVALID_CHECKSUM_STATUS' do |method_sym|
  it 'PreservedCopy keeps INVALID_CHECKSUM_STATUS' do
    pc.status = PreservedCopy::INVALID_CHECKSUM_STATUS
    pc.save!
    po_handler.send(method_sym)
    expect(pc.reload.status).to eq PreservedCopy::INVALID_CHECKSUM_STATUS
  end

  it 'has an AuditResults entry indicating inability to check the given status' do
    pc.status = PreservedCopy::INVALID_CHECKSUM_STATUS
    pc.save!
    po_handler.send(method_sym)
    expect(po_handler.results.contains_result_code?(AuditResults::UNABLE_TO_CHECK_STATUS)).to eq true
  end
end

RSpec.shared_examples 'PreservedCopy may have its status checked when incoming_version == pc.version' do |method_sym|
  let(:incoming_version) { pc.version }

  it 'had OK_STATUS, keeps OK_STATUS' do
    pc.status = PreservedCopy::OK_STATUS
    pc.save!
    allow(po_handler).to receive(:moab_validation_errors).and_return([])
    po_handler.send(method_sym)
    expect(pc.reload.status).to eq PreservedCopy::OK_STATUS
  end
  it 'had UNEXPECTED_VERSION_ON_STORAGE_STATUS, but is now VALIDITY_UNKNOWN_STATUS' do
    pc.status = PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
    pc.save!
    allow(po_handler).to receive(:moab_validation_errors).and_return([])
    po_handler.send(method_sym)
    expect(pc.reload.status).to eq PreservedCopy::VALIDITY_UNKNOWN_STATUS
  end
  it 'had UNEXPECTED_VERSION_ON_STORAGE_STATUS, but is now INVALID_MOAB_STATUS' do
    pc.status = PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
    pc.save!
    allow(po_handler).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
    po_handler.send(method_sym)
    expect(pc.reload.status).to eq PreservedCopy::INVALID_MOAB_STATUS
  end
  it 'had INVALID_MOAB_STATUS, but is now VALIDITY_UNKNOWN_STATUS' do
    pc.status = PreservedCopy::INVALID_MOAB_STATUS
    pc.save!
    allow(po_handler).to receive(:moab_validation_errors).and_return([])
    po_handler.send(method_sym)
    expect(pc.reload.status).to eq PreservedCopy::VALIDITY_UNKNOWN_STATUS
  end
  it 'had VALIDITY_UNKNOWN_STATUS, keeps VALIDITY_UNKNOWN_STATUS' do
    pc.status = PreservedCopy::VALIDITY_UNKNOWN_STATUS
    pc.save!
    allow(po_handler).to receive(:moab_validation_errors).and_return([])
    po_handler.send(method_sym)
    expect(pc.reload.status).to eq PreservedCopy::VALIDITY_UNKNOWN_STATUS
  end
  it 'had VALIDITY_UNKNOWN_STATUS, but is now INVALID_MOAB_STATUS' do
    pc.status = PreservedCopy::VALIDITY_UNKNOWN_STATUS
    pc.save!
    allow(po_handler).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
    po_handler.send(method_sym)
    expect(pc.reload.status).to eq PreservedCopy::INVALID_MOAB_STATUS
  end
  it 'had UNEXPECTED_VERSION_ON_STORAGE_STATUS, seems to have an acceptable version now' do
    pc.status = PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
    pc.save!
    allow(po_handler).to receive(:moab_validation_errors).and_return([])
    po_handler.send(method_sym)
    expect(pc.reload.status).to eq PreservedCopy::VALIDITY_UNKNOWN_STATUS
  end

  context 'had INVALID_CHECKSUM_STATUS' do
    context 'without moab validation errors' do
      before { allow(po_handler).to receive(:moab_validation_errors).and_return([]) }
      it_behaves_like 'cannot validate something with INVALID_CHECKSUM_STATUS', method_sym
    end
    context 'with moab validation errors' do
      before do
        allow(po_handler).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
      end
      it_behaves_like 'cannot validate something with INVALID_CHECKSUM_STATUS', method_sym
    end
  end
end

RSpec.shared_examples 'PreservedCopy may have its status checked when incoming_version < pc.version' do |method_sym|
  let(:incoming_version) { pc.version - 1 }

  it 'had OK_STATUS, but is now UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
    pc.status = PreservedCopy::OK_STATUS
    pc.save!
    allow(po_handler).to receive(:moab_validation_errors).and_return([])
    po_handler.send(method_sym)
    expect(pc.reload.status).to eq PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
  end
  it 'had OK_STATUS, but is now INVALID_MOAB_STATUS' do
    pc.status = PreservedCopy::OK_STATUS
    pc.save!
    allow(po_handler).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
    po_handler.send(method_sym)
    expect(pc.reload.status).to eq PreservedCopy::INVALID_MOAB_STATUS
  end
  it 'had INVALID_MOAB_STATUS, was made to a valid moab, but is now UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
    pc.status = PreservedCopy::INVALID_MOAB_STATUS
    pc.save!
    allow(po_handler).to receive(:moab_validation_errors).and_return([])
    po_handler.send(method_sym)
    expect(pc.reload.status).to eq PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
  end
  it 'had UNEXPECTED_VERSION_ON_STORAGE_STATUS, still seeing an unexpected version' do
    pc.status = PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
    pc.save!
    allow(po_handler).to receive(:moab_validation_errors).and_return([])
    po_handler.send(method_sym)
    expect(pc.reload.status).to eq PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
  end
  it 'had VALIDITY_UNKNOWN_STATUS, but is now INVALID_MOAB_STATUS' do
    pc.status = PreservedCopy::VALIDITY_UNKNOWN_STATUS
    pc.save!
    allow(po_handler).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
    po_handler.send(method_sym)
    expect(pc.reload.status).to eq PreservedCopy::INVALID_MOAB_STATUS
  end
  it 'had VALIDITY_UNKNOWN_STATUS, but is now UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
    pc.status = PreservedCopy::VALIDITY_UNKNOWN_STATUS
    pc.save!
    allow(po_handler).to receive(:moab_validation_errors).and_return([])
    po_handler.send(method_sym)
    expect(pc.reload.status).to eq PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
  end

  context 'had INVALID_CHECKSUM_STATUS' do
    context 'without moab validation errors' do
      before { allow(po_handler).to receive(:moab_validation_errors).and_return([]) }
      it_behaves_like 'cannot validate something with INVALID_CHECKSUM_STATUS', method_sym
    end
    context 'with moab validation errors' do
      before do
        allow(po_handler).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
      end
      it_behaves_like 'cannot validate something with INVALID_CHECKSUM_STATUS', method_sym
    end
  end
end
