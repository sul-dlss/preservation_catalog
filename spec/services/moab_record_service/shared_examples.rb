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
      moab_record_service = described_class.new(druid: bad_druid, incoming_version: bad_version, incoming_size: bad_size,
                                                moab_storage_root: bad_storage_root)
      moab_record_service.execute
    end
    let(:results) { audit_result.results }

    it '1 result' do
      expect(audit_result).to be_an_instance_of Audit::Results
      expect(results.size).to eq 1
    end

    it 'INVALID_ARGUMENTS' do
      expect(results).to include(a_hash_including(Audit::Results::INVALID_ARGUMENTS))
    end

    context 'result message includes' do
      let(:msg) { results.first[Audit::Results::INVALID_ARGUMENTS] }

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
    mock_results = instance_double(Audit::Results,
                                   add_result: nil,
                                   results: [],
                                   results_as_string: nil)
    expect(AuditResultsReporter).to receive(:report_results).with(audit_results: mock_results)
    allow(moab_record_service).to receive(:results).and_return(mock_results)
    moab_record_service.execute
  end
end

RSpec.shared_examples 'druid not in catalog' do
  let(:druid) { 'rr111rr1111' }
  let(:expected_msg) { '[PreservedObject|MoabRecord].* db object does not exist' }
  let(:results) do
    moab_record_service.execute.results
  end

  it 'DB_OBJ_DOES_NOT_EXIST error' do
    raise 'mis-use of shared example: checking behavior when there is no record for the druid' if PreservedObject.exists?(druid: druid)
    expect(results).to include(a_hash_including(Audit::Results::DB_OBJ_DOES_NOT_EXIST => a_string_matching(expected_msg)))
  end
end

RSpec.shared_examples 'MoabRecord does not exist' do
  # expectation is that calling context has a PreservedObject for the druid, but no MoabRecord

  let(:expected_msg) { /MoabRecord.* db object does not exist/ }
  let(:results) do
    moab_record_service.execute.results
  end

  it 'DB_OBJ_DOES_NOT_EXIST error' do
    code = Audit::Results::DB_OBJ_DOES_NOT_EXIST
    expect(results).to include(a_hash_including(code => match(expected_msg)))
  end
end

RSpec.shared_examples 'unexpected version' do |actual_version|
  let(:moab_record_service) do
    described_class.new(druid: druid, incoming_version: actual_version, incoming_size: 1, moab_storage_root: moab_storage_root)
  end
  let(:version_msg_prefix) { "actual version (#{actual_version})" }
  let(:unexpected_version_msg) { "#{version_msg_prefix} has unexpected relationship to MoabRecord db version (2); ERROR!" }

  context 'MoabRecord' do
    context 'changed' do
      it 'last_version_audit' do
        original_moab_record = moab_record.last_version_audit
        moab_record_service.execute
        expect(moab_record.reload.last_version_audit).to be > original_moab_record
      end

      it 'status becomes unexpected_version_on_storage' do
        original_moab_record = moab_record.status
        moab_record_service.execute
        expect(moab_record.reload.status).to eq 'unexpected_version_on_storage'
        expect(moab_record.status).not_to eq original_moab_record
      end
    end

    context 'unchanged' do
      it 'version' do
        original_moab_record = moab_record.version
        moab_record_service.execute
        expect(moab_record.reload.version).to eq original_moab_record
      end

      it 'size' do
        original_moab_record = moab_record.size
        moab_record_service.execute
        expect(moab_record.reload.size).to eq original_moab_record
      end

      it 'last_moab_validation' do
        original_moab_record = moab_record.last_moab_validation
        moab_record_service.execute
        expect(moab_record.reload.last_moab_validation).to eq original_moab_record
      end
    end
  end

  context 'PreservedObject' do
    context 'unchanged' do
      it 'PreservedObject current_version stays the same' do
        preserved_object_current_version = preserved_object.current_version
        moab_record_service.execute
        expect(preserved_object.reload.current_version).to eq preserved_object_current_version
      end
    end
  end

  context 'returns' do
    let!(:audit_result) { moab_record_service.execute }
    let(:results) { audit_result.results }

    it 'number of results' do
      expect(audit_result).to be_an_instance_of Audit::Results
      expect(results.size).to eq 3
    end

    it 'UNEXPECTED_VERSION result' do
      code = Audit::Results::UNEXPECTED_VERSION
      expect(results).to include(a_hash_including(code => unexpected_version_msg))
    end

    it 'specific version results' do
      # NOTE: this is not checking that we have the CORRECT specific code
      codes = [
        Audit::Results::VERSION_MATCHES,
        Audit::Results::ACTUAL_VERS_GT_DB_OBJ,
        Audit::Results::ACTUAL_VERS_LT_DB_OBJ
      ]
      object_version_results = results.select { |r| codes.include?(r.keys.first) }
      msgs = object_version_results.map { |r| r.values.first }
      expect(msgs).to include(a_string_matching('MoabRecord'))
    end

    it 'MOAB_RECORD_STATUS_CHANGED result' do
      expect(results).to include(a_hash_including(Audit::Results::MOAB_RECORD_STATUS_CHANGED))
    end
  end
end

RSpec.shared_examples 'unexpected version with validation' do |service, incoming_version, new_status|
  let(:moab_record_service) do
    described_class.new(druid: druid, incoming_version: incoming_version, incoming_size: 1, moab_storage_root: moab_storage_root)
  end

  let(:version_msg_prefix) { "actual version (#{incoming_version})" }
  let(:unexpected_version_msg) { "#{version_msg_prefix} has unexpected relationship to MoabRecord db version; ERROR!" }
  let(:updated_status_msg_regex) { Regexp.new('MoabRecord status changed from') }

  context 'MoabRecord' do
    it 'last_moab_validation updated' do
      expect { moab_record_service.execute }.to change { moab_record.reload.last_moab_validation }
    end

    it 'version unchanged' do
      expect { moab_record_service.execute }.not_to change { moab_record.reload.version }
    end

    it 'size unchanged' do
      expect { moab_record_service.execute }.not_to change { moab_record.reload.size }
    end

    describe 'last_version_audit' do
      if service == :check_existence
        it 'updated' do
          expect { moab_record_service.execute }.to change { moab_record.reload.last_version_audit }
        end
      end
    end

    describe 'status becomes' do
      before { moab_record.ok! }

      if service == :update_version_after_validation
        it "#{new_status} when checksums_validated" do
          expect { moab_record_service.execute(checksums_validated: true) }.to change { moab_record.reload.status }.from('ok').to(new_status)
        end

        it 'validity_unknown when not checksums_validated' do
          expect { moab_record_service.execute }.to change { moab_record.reload.status }.from('ok').to('validity_unknown')
        end

      else
        it new_status do
          expect { moab_record_service.execute }.to change { moab_record.reload.status }.from('ok').to(new_status)
        end
      end
    end
  end

  context 'PreservedObject' do
    it 'current_version' do
      expect { moab_record_service.execute }.not_to change { preserved_object.reload.current_version }
    end
  end

  context 'returns' do
    let!(:results) { moab_record_service.execute.results }

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
        unless results.find { |result| result.keys.first == Audit::Results::INVALID_MOAB }
          code = Audit::Results::UNEXPECTED_VERSION
          expect(results).to include(a_hash_including(code => unexpected_version_msg))
        end
      end
    end
    it 'specific version results' do
      codes = [
        Audit::Results::VERSION_MATCHES,
        Audit::Results::ACTUAL_VERS_GT_DB_OBJ,
        Audit::Results::ACTUAL_VERS_LT_DB_OBJ
      ]
      object_version_results = results.select { |r| codes.include?(r.keys.first) }
      msgs = object_version_results.map { |r| r.values.first }
      expect(msgs).to include(a_string_matching('MoabRecord')) unless results.find { |r| r.keys.first == Audit::Results::INVALID_MOAB }
    end

    it 'MOAB_RECORD_STATUS_CHANGED result' do
      expect(results).to include(a_hash_including(Audit::Results::MOAB_RECORD_STATUS_CHANGED => updated_status_msg_regex))
    end
  end
end

RSpec.shared_examples 'PreservedObject current_version does not match MoabRecord version' do |incoming_version, moab_record_v, po_v|
  let(:moab_record_service) do
    described_class.new(druid: druid, incoming_version: incoming_version, incoming_size: 1, moab_storage_root: moab_storage_root)
  end
  let(:version_mismatch_msg) { "MoabRecord version #{moab_record_v} does not match PreservedObject current_version #{po_v}" }

  it 'does not update MoabRecord' do
    original_moab_record = moab_record.reload.updated_at
    moab_record_service.execute
    expect(moab_record.reload.updated_at).to eq original_moab_record
  end

  it 'does not update PreservedObject' do
    original_moab_record = preserved_object.reload.updated_at
    moab_record_service.execute
    expect(preserved_object.reload.updated_at).to eq original_moab_record
  end

  context 'returns' do
    let!(:audit_result) { moab_record_service.execute }
    let(:results) { audit_result.results }

    it '1 result' do
      expect(audit_result).to be_an_instance_of Audit::Results
      expect(results.size).to eq 1
    end

    it 'DB_VERSIONS_DISAGREE result' do
      code = Audit::Results::DB_VERSIONS_DISAGREE
      expect(results).to include(hash_including(code => version_mismatch_msg))
    end
  end
end

RSpec.shared_examples 'cannot validate something with INVALID_CHECKSUM_STATUS' do
  before { moab_record.invalid_checksum! }

  it 'MoabRecord keeps INVALID_CHECKSUM_STATUS' do
    moab_record_service.execute
    expect(moab_record.reload.status).to eq 'invalid_checksum'
  end

  it 'has an Audit::Results entry indicating inability to check the given status' do
    moab_record_service.execute
    expect(moab_record_service.results.contains_result_code?(Audit::Results::UNABLE_TO_CHECK_STATUS)).to be true
  end
end

RSpec.shared_examples 'MoabRecord may have its status checked when incoming_version == moab_record.version' do
  let(:incoming_version) { moab_record.version }
  let(:moab_on_storage_validator) { moab_record_service.send(:moab_on_storage_validator) }

  before { allow(moab_on_storage_validator).to receive(:moab_validation_errors).and_return([]) } # default

  it 'had OK_STATUS, keeps OK_STATUS' do
    moab_record.ok!
    moab_record_service.execute
    expect(moab_record.reload.status).to eq 'ok'
  end

  it 'had UNEXPECTED_VERSION_ON_STORAGE_STATUS, but is now VALIDITY_UNKNOWN_STATUS' do
    moab_record.unexpected_version_on_storage!
    moab_record_service.execute
    expect(moab_record.reload.status).to eq 'validity_unknown'
  end

  it 'had UNEXPECTED_VERSION_ON_STORAGE_STATUS, but is now INVALID_MOAB_STATUS' do
    moab_record.unexpected_version_on_storage!
    allow(moab_on_storage_validator).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
    moab_record_service.execute
    expect(moab_record.reload.status).to eq 'invalid_moab'
  end

  it 'had INVALID_MOAB_STATUS, but is now VALIDITY_UNKNOWN_STATUS' do
    moab_record.invalid_moab!
    moab_record_service.execute
    expect(moab_record.reload.status).to eq 'validity_unknown'
  end

  it 'had VALIDITY_UNKNOWN_STATUS, keeps VALIDITY_UNKNOWN_STATUS' do
    moab_record.validity_unknown!
    moab_record_service.execute
    expect(moab_record.reload.status).to eq 'validity_unknown'
  end

  it 'had VALIDITY_UNKNOWN_STATUS, but is now INVALID_MOAB_STATUS' do
    moab_record.validity_unknown!
    allow(moab_on_storage_validator).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
    moab_record_service.execute
    expect(moab_record.reload.status).to eq 'invalid_moab'
  end

  it 'had UNEXPECTED_VERSION_ON_STORAGE_STATUS, seems to have an acceptable version now' do
    moab_record.unexpected_version_on_storage!
    moab_record_service.execute
    expect(moab_record.reload.status).to eq 'validity_unknown'
  end

  context 'had INVALID_CHECKSUM_STATUS' do
    context 'without moab validation errors' do
      it_behaves_like 'cannot validate something with INVALID_CHECKSUM_STATUS'
    end

    context 'with moab validation errors' do
      before do
        allow(moab_on_storage_validator).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
      end

      it_behaves_like 'cannot validate something with INVALID_CHECKSUM_STATUS'
    end
  end
end

RSpec.shared_examples 'MoabRecord may have its status checked when incoming_version < moab_record.version' do
  let(:incoming_version) { moab_record.version - 1 }
  let(:moab_on_storage_validator) { moab_record_service.send(:moab_on_storage_validator) }

  before { allow(moab_on_storage_validator).to receive(:moab_validation_errors).and_return([]) } # default

  it 'had OK_STATUS, but is now UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
    moab_record.ok!
    moab_record_service.execute
    expect(moab_record.reload.status).to eq 'unexpected_version_on_storage'
  end

  it 'had OK_STATUS, but is now INVALID_MOAB_STATUS' do
    moab_record.ok!
    allow(moab_on_storage_validator).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
    moab_record_service.execute
    expect(moab_record.reload.status).to eq 'invalid_moab'
  end

  it 'had INVALID_MOAB_STATUS, was made to a valid moab, but is now UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
    moab_record.invalid_moab!
    moab_record_service.execute
    expect(moab_record.reload.status).to eq 'unexpected_version_on_storage'
  end

  it 'had UNEXPECTED_VERSION_ON_STORAGE_STATUS, still seeing an unexpected version' do
    moab_record.unexpected_version_on_storage!
    moab_record_service.execute
    expect(moab_record.reload.status).to eq 'unexpected_version_on_storage'
  end

  it 'had VALIDITY_UNKNOWN_STATUS, but is now INVALID_MOAB_STATUS' do
    moab_record.validity_unknown!
    allow(moab_on_storage_validator).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
    moab_record_service.execute
    expect(moab_record.reload.status).to eq 'invalid_moab'
  end

  it 'had VALIDITY_UNKNOWN_STATUS, but is now UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
    moab_record.validity_unknown!
    moab_record_service.execute
    expect(moab_record.reload.status).to eq 'unexpected_version_on_storage'
  end

  context 'had INVALID_CHECKSUM_STATUS' do
    context 'without moab validation errors' do
      it_behaves_like 'cannot validate something with INVALID_CHECKSUM_STATUS'
    end

    context 'with moab validation errors' do
      before do
        allow(moab_on_storage_validator).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
      end

      it_behaves_like 'cannot validate something with INVALID_CHECKSUM_STATUS'
    end
  end
end
