RSpec.shared_examples "attributes validated" do |method_sym|
  let(:bad_druid) { '666' }
  let(:bad_version) { 'vv666' }
  let(:bad_size) { '-666' }
  let(:bad_storage_root) { nil }
  let(:bad_druid_msg) { 'Druid is invalid' }
  let(:bad_version_msg) { 'Incoming version is not a number' }
  let(:bad_size_msg) { 'Incoming size must be greater than 0' }
  let(:bad_storage_root_msg) { "Moab storage root must be an actual MoabStorageRoot" }

  context 'returns' do
    let!(:result) do
      po_handler = described_class.new(bad_druid, bad_version, bad_size, bad_storage_root)
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
      it "moab_storage_root error" do
        expect(msg).to match(bad_storage_root_msg)
      end
    end
  end
end

RSpec.shared_examples 'calls AuditResults.report_results' do |method_sym|
  it 'outputs results to Rails.logger and sends errors to WorkflowErrorReporter' do
    mock_results = instance_double(AuditResults, add_result: nil, :check_name= => nil)
    expect(mock_results).to receive(:report_results)
    allow(po_handler).to receive(:results).and_return(mock_results)
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
    expect(results).to include(a_hash_including(AuditResults::DB_OBJ_DOES_NOT_EXIST => a_string_matching(exp_msg)))
  end
end

RSpec.shared_examples 'CompleteMoab does not exist' do |method_sym|
  let(:exp_msg) { "#<ActiveRecord::RecordNotFound: foo> db object does not exist" }
  let(:results) do
    allow(Rails.logger).to receive(:log)
    allow(po_handler).to receive(:pres_object).and_return(create(:preserved_object))
    allow(PreservedObject).to receive(:exists?).with(druid: po_handler.druid).and_return(true)
    allow(po_handler.pres_object.complete_moabs).to receive(:find_by!)
      .with(any_args).and_raise(ActiveRecord::RecordNotFound, 'foo')
    po_handler.send(method_sym)
  end

  it 'DB_OBJ_DOES_NOT_EXIST error' do
    code = AuditResults::DB_OBJ_DOES_NOT_EXIST
    expect(results).to include(a_hash_including(code => exp_msg))
  end
end

RSpec.shared_examples 'unexpected version' do |method_sym, actual_version|
  let(:po_handler) { described_class.new(druid, actual_version, 1, ms_root) }
  let(:version_msg_prefix) { "actual version (#{actual_version})" }
  let(:unexpected_version_msg) { "#{version_msg_prefix} has unexpected relationship to CompleteMoab db version (2); ERROR!" }

  context 'CompleteMoab' do
    context 'changed' do
      it 'last_version_audit' do
        orig = cm.last_version_audit
        po_handler.send(method_sym)
        expect(cm.reload.last_version_audit).to be > orig
      end
      if method_sym == :update_version
        it 'status becomes unexpected_version_on_storage' do
          orig = cm.status
          po_handler.send(method_sym)
          expect(cm.reload.status).to eq 'unexpected_version_on_storage'
          expect(cm.status).not_to eq orig
        end
        it 'status becomes unexpected_version_on_storage when checksums_validated' do
          orig = cm.status
          po_handler.send(method_sym, true)
          expect(cm.reload.status).to eq "unexpected_version_on_storage"
          expect(cm.status).not_to eq orig
        end
      end
    end

    context 'unchanged' do
      it "version" do
        orig = cm.version
        po_handler.send(method_sym)
        expect(cm.reload.version).to eq orig
      end
      it "size" do
        orig = cm.size
        po_handler.send(method_sym)
        expect(cm.reload.size).to eq orig
      end
      it 'last_moab_validation' do
        orig = cm.last_moab_validation
        po_handler.send(method_sym)
        expect(cm.reload.last_moab_validation).to eq orig
      end
      if method_sym != :update_version
        it 'status' do
          orig = cm.status
          po_handler.send(method_sym)
          expect(cm.status).to eq orig
        end
        it 'status when checksums_validated' do
          orig = cm.status
          po_handler.send(method_sym, true)
          expect(cm.status).to eq orig
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
      expect(msgs).to include(a_string_matching("CompleteMoab"))
    end
    if method_sym == :update_version
      it 'CM_STATUS_CHANGED result' do
        expect(results).to include(a_hash_including(AuditResults::CM_STATUS_CHANGED))
      end
    else
      it 'no CM_STATUS_CHANGED result' do
        expect(results).not_to include(a_hash_including(AuditResults::CM_STATUS_CHANGED))
      end
    end
  end
end

RSpec.shared_examples 'unexpected version with validation' do |method_sym, incoming_version, new_status|
  let(:po_handler) { described_class.new(druid, incoming_version, 1, ms_root) }
  let(:version_msg_prefix) { "actual version (#{incoming_version})" }
  let(:unexpected_version_msg) { "#{version_msg_prefix} has unexpected relationship to CompleteMoab db version; ERROR!" }
  let(:updated_status_msg_regex) { Regexp.new("CompleteMoab status changed from") }

  context 'CompleteMoab' do
    it 'last_moab_validation updated' do
      expect { po_handler.send(method_sym) }.to change { cm.reload.last_moab_validation }
    end
    it "version unchanged" do
      expect { po_handler.send(method_sym) }.not_to change { cm.reload.version }
    end
    it "size unchanged" do
      expect { po_handler.send(method_sym) }.not_to change { cm.reload.size }
    end
    describe 'last_version_audit' do
      if method_sym == :check_existence
        it 'updated' do
          expect { po_handler.send(method_sym) }.to change { cm.reload.last_version_audit }
        end
      elsif method_sym == :update_version
        it 'unchanged' do
          expect { po_handler.send(method_sym) }.not_to change { cm.reload.last_version_audit }
        end
      end
    end

    describe 'status becomes' do
      before { cm.ok! }

      if method_sym == :update_version_after_validation
        it "#{new_status} when checksums_validated" do
          expect { po_handler.send(method_sym, true) }.to change { cm.reload.status }.from('ok').to(new_status)
        end
        it "validity_unknown when not checksums_validated" do
          expect { po_handler.send(method_sym) }.to change { cm.reload.status }.from('ok').to('validity_unknown')
        end
      else
        it new_status do
          expect { po_handler.send(method_sym) }.to change { cm.reload.status }.from('ok').to(new_status)
        end
      end
    end
  end

  context 'PreservedObject' do
    it "current_version" do
      expect { po_handler.send(method_sym) }.not_to change { po.reload.current_version }
    end
  end

  context 'returns' do
    let!(:results) { po_handler.send(method_sym) }

    it "number of results" do
      expect(results).to be_an_instance_of Array
      if method_sym == :check_existence
        expect(results.size).to eq 2
      elsif method_sym == :update_version_after_validation
        expect(results.size).to eq 4
      end
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
        expect(msgs).to include(a_string_matching("CompleteMoab"))
      end
    end
    it 'CM_STATUS_CHANGED result' do
      expect(results).to include(a_hash_including(AuditResults::CM_STATUS_CHANGED => updated_status_msg_regex))
    end
  end
end

RSpec.shared_examples 'PreservedObject current_version does not match online CM version' do |method_sym, incoming_version, cm_v, po_v|
  let(:po_handler) { described_class.new(druid, incoming_version, 1, ms_root) }
  let(:version_mismatch_msg) { "CompleteMoab online Moab version #{cm_v} does not match PreservedObject current_version #{po_v}" }

  it 'does not update CompleteMoab' do
    orig = cm.reload.updated_at
    po_handler.send(method_sym)
    expect(cm.reload.updated_at).to eq orig
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
    it 'CM_PO_VERSION_MISMATCH result' do
      code = AuditResults::CM_PO_VERSION_MISMATCH
      expect(results).to include(hash_including(code => version_mismatch_msg))
    end
  end
end

RSpec.shared_examples 'cannot validate something with INVALID_CHECKSUM_STATUS' do |method_sym|
  before { cm.invalid_checksum! }

  it 'CompleteMoab keeps INVALID_CHECKSUM_STATUS' do
    po_handler.send(method_sym)
    expect(cm.reload.status).to eq 'invalid_checksum'
  end

  it 'has an AuditResults entry indicating inability to check the given status' do
    po_handler.send(method_sym)
    expect(po_handler.results.contains_result_code?(AuditResults::UNABLE_TO_CHECK_STATUS)).to eq true
  end
end

RSpec.shared_examples 'CompleteMoab may have its status checked when incoming_version == cm.version' do |method_sym|
  let(:incoming_version) { cm.version }

  before { allow(po_handler).to receive(:moab_validation_errors).and_return([]) } # default

  it 'had OK_STATUS, keeps OK_STATUS' do
    cm.ok!
    po_handler.send(method_sym)
    expect(cm.reload.status).to eq 'ok'
  end
  it 'had UNEXPECTED_VERSION_ON_STORAGE_STATUS, but is now VALIDITY_UNKNOWN_STATUS' do
    cm.unexpected_version_on_storage!
    po_handler.send(method_sym)
    expect(cm.reload.status).to eq 'validity_unknown'
  end
  it 'had UNEXPECTED_VERSION_ON_STORAGE_STATUS, but is now INVALID_MOAB_STATUS' do
    cm.unexpected_version_on_storage!
    allow(po_handler).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
    po_handler.send(method_sym)
    expect(cm.reload.status).to eq 'invalid_moab'
  end
  it 'had INVALID_MOAB_STATUS, but is now VALIDITY_UNKNOWN_STATUS' do
    cm.invalid_moab!
    po_handler.send(method_sym)
    expect(cm.reload.status).to eq 'validity_unknown'
  end
  it 'had VALIDITY_UNKNOWN_STATUS, keeps VALIDITY_UNKNOWN_STATUS' do
    cm.validity_unknown!
    po_handler.send(method_sym)
    expect(cm.reload.status).to eq 'validity_unknown'
  end
  it 'had VALIDITY_UNKNOWN_STATUS, but is now INVALID_MOAB_STATUS' do
    cm.validity_unknown!
    allow(po_handler).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
    po_handler.send(method_sym)
    expect(cm.reload.status).to eq 'invalid_moab'
  end
  it 'had UNEXPECTED_VERSION_ON_STORAGE_STATUS, seems to have an acceptable version now' do
    cm.unexpected_version_on_storage!
    po_handler.send(method_sym)
    expect(cm.reload.status).to eq 'validity_unknown'
  end

  context 'had INVALID_CHECKSUM_STATUS' do
    context 'without moab validation errors' do
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

RSpec.shared_examples 'CompleteMoab may have its status checked when incoming_version < cm.version' do |method_sym|
  let(:incoming_version) { cm.version - 1 }

  before { allow(po_handler).to receive(:moab_validation_errors).and_return([]) } # default

  it 'had OK_STATUS, but is now UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
    cm.ok!
    po_handler.send(method_sym)
    expect(cm.reload.status).to eq 'unexpected_version_on_storage'
  end
  it 'had OK_STATUS, but is now INVALID_MOAB_STATUS' do
    cm.ok!
    allow(po_handler).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
    po_handler.send(method_sym)
    expect(cm.reload.status).to eq 'invalid_moab'
  end
  it 'had INVALID_MOAB_STATUS, was made to a valid moab, but is now UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
    cm.invalid_moab!
    po_handler.send(method_sym)
    expect(cm.reload.status).to eq 'unexpected_version_on_storage'
  end
  it 'had UNEXPECTED_VERSION_ON_STORAGE_STATUS, still seeing an unexpected version' do
    cm.unexpected_version_on_storage!
    po_handler.send(method_sym)
    expect(cm.reload.status).to eq 'unexpected_version_on_storage'
  end
  it 'had VALIDITY_UNKNOWN_STATUS, but is now INVALID_MOAB_STATUS' do
    cm.validity_unknown!
    allow(po_handler).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
    po_handler.send(method_sym)
    expect(cm.reload.status).to eq 'invalid_moab'
  end
  it 'had VALIDITY_UNKNOWN_STATUS, but is now UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
    cm.validity_unknown!
    po_handler.send(method_sym)
    expect(cm.reload.status).to eq 'unexpected_version_on_storage'
  end

  context 'had INVALID_CHECKSUM_STATUS' do
    context 'without moab validation errors' do
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
