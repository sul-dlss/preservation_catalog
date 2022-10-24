# frozen_string_literal: true

RSpec.shared_examples 'attributes validated' do
  let(:bad_druid) { '666' }
  let(:bad_version) { 'vv666' }
  let(:bad_size) { '-666' }
  let(:bad_storage_root) { nil }
  let(:bad_druid_msg) { 'Druid is invalid' }
  let(:bad_version_msg) { 'Incoming version is not a number' }
  let(:bad_size_msg) { 'Incoming size must be greater than 0' }
  let(:bad_storage_root_msg) { 'Moab storage root must be an actual MoabStorageRoot' }

  context 'returns' do
    let!(:audit_result) do
      complete_moab_handler = described_class.new(druid: bad_druid, incoming_version: bad_version, incoming_size: bad_size,
                                                  moab_storage_root: bad_storage_root)
      complete_moab_handler.execute
    end
    let(:results) { audit_result.results }

    it '1 result' do
      expect(audit_result).to be_an_instance_of AuditResults
      expect(results.size).to eq 1
    end

    it 'INVALID_ARGUMENTS' do
      expect(results).to include(a_hash_including(AuditResults::INVALID_ARGUMENTS))
    end

    context 'result message includes' do
      let(:msg) { results.first[AuditResults::INVALID_ARGUMENTS] }

      it 'prefix' do
        expect(msg).to match(Regexp.escape('encountered validation error(s): '))
      end

      it 'druid error' do
        expect(msg).to match(bad_druid_msg)
      end

      it 'version error' do
        expect(msg).to match(bad_version_msg)
      end

      it 'size error' do
        expect(msg).to match(bad_size_msg)
      end

      it 'moab_storage_root error' do
        expect(msg).to match(bad_storage_root_msg)
      end
    end
  end
end

RSpec.shared_examples 'calls AuditResultsReporter.report_results' do
  it 'outputs results to Rails.logger and sends errors to WorkflowErrorReporter' do
    mock_results = instance_double(AuditResults,
                                   add_result: nil,
                                   :check_name= => nil,
                                   results: [],
                                   results_as_string: nil)
    expect(AuditResultsReporter).to receive(:report_results).with(audit_results: mock_results)
    allow(complete_moab_handler).to receive(:results).and_return(mock_results)
    complete_moab_handler.execute
  end
end

RSpec.shared_examples 'druid not in catalog' do
  let(:druid) { 'rr111rr1111' }
  let(:exp_msg) { '[PreservedObject|CompleteMoab].* db object does not exist' }
  let(:results) do
    complete_moab_handler.execute.results
  end

  it 'DB_OBJ_DOES_NOT_EXIST error' do
    raise 'mis-use of shared example: checking behavior when there is no record for the druid' if PreservedObject.exists?(druid: druid)
    expect(results).to include(a_hash_including(AuditResults::DB_OBJ_DOES_NOT_EXIST => a_string_matching(exp_msg)))
  end
end

RSpec.shared_examples 'CompleteMoab does not exist' do
  # expectation is that calling context has a PreservedObject for the druid, but no CompleteMoab

  let(:exp_msg) { /CompleteMoab.* db object does not exist/ }
  let(:results) do
    complete_moab_handler.execute.results
  end

  it 'DB_OBJ_DOES_NOT_EXIST error' do
    code = AuditResults::DB_OBJ_DOES_NOT_EXIST
    expect(results).to include(a_hash_including(code => match(exp_msg)))
  end
end

RSpec.shared_examples 'unexpected version' do |actual_version|
  let(:complete_moab_handler) { described_class.new(druid: druid, incoming_version: actual_version, incoming_size: 1, moab_storage_root: ms_root) }
  let(:version_msg_prefix) { "actual version (#{actual_version})" }
  let(:unexpected_version_msg) { "#{version_msg_prefix} has unexpected relationship to CompleteMoab db version (2); ERROR!" }

  context 'CompleteMoab' do
    context 'changed' do
      it 'last_version_audit' do
        orig = cm.last_version_audit
        complete_moab_handler.execute
        expect(cm.reload.last_version_audit).to be > orig
      end

      it 'status becomes unexpected_version_on_storage' do
        orig = cm.status
        complete_moab_handler.execute
        expect(cm.reload.status).to eq 'unexpected_version_on_storage'
        expect(cm.status).not_to eq orig
      end
    end

    context 'unchanged' do
      it 'version' do
        orig = cm.version
        complete_moab_handler.execute
        expect(cm.reload.version).to eq orig
      end

      it 'size' do
        orig = cm.size
        complete_moab_handler.execute
        expect(cm.reload.size).to eq orig
      end

      it 'last_moab_validation' do
        orig = cm.last_moab_validation
        complete_moab_handler.execute
        expect(cm.reload.last_moab_validation).to eq orig
      end
    end
  end

  context 'PreservedObject' do
    context 'unchanged' do
      it 'PreservedObject current_version stays the same' do
        pocv = po.current_version
        complete_moab_handler.execute
        expect(po.reload.current_version).to eq pocv
      end
    end
  end

  context 'returns' do
    let!(:audit_result) { complete_moab_handler.execute }
    let(:results) { audit_result.results }

    it 'number of results' do
      expect(audit_result).to be_an_instance_of AuditResults
      expect(results.size).to eq 3
    end

    it 'UNEXPECTED_VERSION result' do
      code = AuditResults::UNEXPECTED_VERSION
      expect(results).to include(a_hash_including(code => unexpected_version_msg))
    end

    it 'specific version results' do
      # NOTE: this is not checking that we have the CORRECT specific code
      codes = [
        AuditResults::VERSION_MATCHES,
        AuditResults::ACTUAL_VERS_GT_DB_OBJ,
        AuditResults::ACTUAL_VERS_LT_DB_OBJ
      ]
      obj_version_results = results.select { |r| codes.include?(r.keys.first) }
      msgs = obj_version_results.map { |r| r.values.first }
      expect(msgs).to include(a_string_matching('CompleteMoab'))
    end

    it 'CM_STATUS_CHANGED result' do
      expect(results).to include(a_hash_including(AuditResults::CM_STATUS_CHANGED))
    end
  end
end

RSpec.shared_examples 'unexpected version with validation' do |service, incoming_version, new_status|
  let(:complete_moab_handler) { described_class.new(druid: druid, incoming_version: incoming_version, incoming_size: 1, moab_storage_root: ms_root) }

  let(:version_msg_prefix) { "actual version (#{incoming_version})" }
  let(:unexpected_version_msg) { "#{version_msg_prefix} has unexpected relationship to CompleteMoab db version; ERROR!" }
  let(:updated_status_msg_regex) { Regexp.new('CompleteMoab status changed from') }

  context 'CompleteMoab' do
    it 'last_moab_validation updated' do
      expect { complete_moab_handler.execute }.to change { cm.reload.last_moab_validation }
    end

    it 'version unchanged' do
      expect { complete_moab_handler.execute }.not_to change { cm.reload.version }
    end

    it 'size unchanged' do
      expect { complete_moab_handler.execute }.not_to change { cm.reload.size }
    end

    describe 'last_version_audit' do
      if service == :check_existence
        it 'updated' do
          expect { complete_moab_handler.execute }.to change { cm.reload.last_version_audit }
        end
      end
    end

    describe 'status becomes' do
      before { cm.ok! }

      if service == :update_version_after_validation
        it "#{new_status} when checksums_validated" do
          expect { complete_moab_handler.execute(checksums_validated: true) }.to change { cm.reload.status }.from('ok').to(new_status)
        end

        it 'validity_unknown when not checksums_validated' do
          expect { complete_moab_handler.execute }.to change { cm.reload.status }.from('ok').to('validity_unknown')
        end

      else
        it new_status do
          expect { complete_moab_handler.execute }.to change { cm.reload.status }.from('ok').to(new_status)
        end
      end
    end
  end

  context 'PreservedObject' do
    it 'current_version' do
      expect { complete_moab_handler.execute }.not_to change { po.reload.current_version }
    end
  end

  context 'returns' do
    let!(:results) { complete_moab_handler.execute.results }

    it 'number of results' do
      expect(results).to be_an_instance_of Array
      case service
      when :check_existence
        expect(results.size).to eq 2
      when :update_version_after_validation
        expect(results.size).to eq 4
      end
    end

    if service == :update_version_after_validation
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
      expect(msgs).to include(a_string_matching('CompleteMoab')) unless results.find { |r| r.keys.first == AuditResults::INVALID_MOAB }
    end

    it 'CM_STATUS_CHANGED result' do
      expect(results).to include(a_hash_including(AuditResults::CM_STATUS_CHANGED => updated_status_msg_regex))
    end
  end
end

RSpec.shared_examples 'PreservedObject current_version does not match online CM version' do |incoming_version, cm_v, po_v|
  let(:complete_moab_handler) { described_class.new(druid: druid, incoming_version: incoming_version, incoming_size: 1, moab_storage_root: ms_root) }
  let(:version_mismatch_msg) { "CompleteMoab online Moab version #{cm_v} does not match PreservedObject current_version #{po_v}" }

  it 'does not update CompleteMoab' do
    orig = cm.reload.updated_at
    complete_moab_handler.execute
    expect(cm.reload.updated_at).to eq orig
  end

  it 'does not update PreservedObject' do
    orig = po.reload.updated_at
    complete_moab_handler.execute
    expect(po.reload.updated_at).to eq orig
  end

  context 'returns' do
    let!(:audit_result) { complete_moab_handler.execute }
    let(:results) { audit_result.results }

    it '1 result' do
      expect(audit_result).to be_an_instance_of AuditResults
      expect(results.size).to eq 1
    end

    it 'CM_PO_VERSION_MISMATCH result' do
      code = AuditResults::CM_PO_VERSION_MISMATCH
      expect(results).to include(hash_including(code => version_mismatch_msg))
    end
  end
end

RSpec.shared_examples 'cannot validate something with INVALID_CHECKSUM_STATUS' do
  before { cm.invalid_checksum! }

  it 'CompleteMoab keeps INVALID_CHECKSUM_STATUS' do
    complete_moab_handler.execute
    expect(cm.reload.status).to eq 'invalid_checksum'
  end

  it 'has an AuditResults entry indicating inability to check the given status' do
    complete_moab_handler.execute
    expect(complete_moab_handler.results.contains_result_code?(AuditResults::UNABLE_TO_CHECK_STATUS)).to be true
  end
end

RSpec.shared_examples 'CompleteMoab may have its status checked when incoming_version == cm.version' do
  let(:incoming_version) { cm.version }
  let(:moab_validator) { complete_moab_handler.send(:moab_validator) }

  before { allow(moab_validator).to receive(:moab_validation_errors).and_return([]) } # default

  it 'had OK_STATUS, keeps OK_STATUS' do
    cm.ok!
    complete_moab_handler.execute
    expect(cm.reload.status).to eq 'ok'
  end

  it 'had UNEXPECTED_VERSION_ON_STORAGE_STATUS, but is now VALIDITY_UNKNOWN_STATUS' do
    cm.unexpected_version_on_storage!
    complete_moab_handler.execute
    expect(cm.reload.status).to eq 'validity_unknown'
  end

  it 'had UNEXPECTED_VERSION_ON_STORAGE_STATUS, but is now INVALID_MOAB_STATUS' do
    cm.unexpected_version_on_storage!
    allow(moab_validator).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
    complete_moab_handler.execute
    expect(cm.reload.status).to eq 'invalid_moab'
  end

  it 'had INVALID_MOAB_STATUS, but is now VALIDITY_UNKNOWN_STATUS' do
    cm.invalid_moab!
    complete_moab_handler.execute
    expect(cm.reload.status).to eq 'validity_unknown'
  end

  it 'had VALIDITY_UNKNOWN_STATUS, keeps VALIDITY_UNKNOWN_STATUS' do
    cm.validity_unknown!
    complete_moab_handler.execute
    expect(cm.reload.status).to eq 'validity_unknown'
  end

  it 'had VALIDITY_UNKNOWN_STATUS, but is now INVALID_MOAB_STATUS' do
    cm.validity_unknown!
    allow(moab_validator).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
    complete_moab_handler.execute
    expect(cm.reload.status).to eq 'invalid_moab'
  end

  it 'had UNEXPECTED_VERSION_ON_STORAGE_STATUS, seems to have an acceptable version now' do
    cm.unexpected_version_on_storage!
    complete_moab_handler.execute
    expect(cm.reload.status).to eq 'validity_unknown'
  end

  context 'had INVALID_CHECKSUM_STATUS' do
    context 'without moab validation errors' do
      it_behaves_like 'cannot validate something with INVALID_CHECKSUM_STATUS'
    end

    context 'with moab validation errors' do
      before do
        allow(moab_validator).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
      end

      it_behaves_like 'cannot validate something with INVALID_CHECKSUM_STATUS'
    end
  end
end

RSpec.shared_examples 'CompleteMoab may have its status checked when incoming_version < cm.version' do
  let(:incoming_version) { cm.version - 1 }
  let(:moab_validator) { complete_moab_handler.send(:moab_validator) }

  before { allow(moab_validator).to receive(:moab_validation_errors).and_return([]) } # default

  it 'had OK_STATUS, but is now UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
    cm.ok!
    complete_moab_handler.execute
    expect(cm.reload.status).to eq 'unexpected_version_on_storage'
  end

  it 'had OK_STATUS, but is now INVALID_MOAB_STATUS' do
    cm.ok!
    allow(moab_validator).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
    complete_moab_handler.execute
    expect(cm.reload.status).to eq 'invalid_moab'
  end

  it 'had INVALID_MOAB_STATUS, was made to a valid moab, but is now UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
    cm.invalid_moab!
    complete_moab_handler.execute
    expect(cm.reload.status).to eq 'unexpected_version_on_storage'
  end

  it 'had UNEXPECTED_VERSION_ON_STORAGE_STATUS, still seeing an unexpected version' do
    cm.unexpected_version_on_storage!
    complete_moab_handler.execute
    expect(cm.reload.status).to eq 'unexpected_version_on_storage'
  end

  it 'had VALIDITY_UNKNOWN_STATUS, but is now INVALID_MOAB_STATUS' do
    cm.validity_unknown!
    allow(moab_validator).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
    complete_moab_handler.execute
    expect(cm.reload.status).to eq 'invalid_moab'
  end

  it 'had VALIDITY_UNKNOWN_STATUS, but is now UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
    cm.validity_unknown!
    complete_moab_handler.execute
    expect(cm.reload.status).to eq 'unexpected_version_on_storage'
  end

  context 'had INVALID_CHECKSUM_STATUS' do
    context 'without moab validation errors' do
      it_behaves_like 'cannot validate something with INVALID_CHECKSUM_STATUS'
    end

    context 'with moab validation errors' do
      before do
        allow(moab_validator).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
      end

      it_behaves_like 'cannot validate something with INVALID_CHECKSUM_STATUS'
    end
  end
end
