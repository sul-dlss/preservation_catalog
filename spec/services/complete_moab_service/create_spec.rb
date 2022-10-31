# frozen_string_literal: true

require 'rails_helper'
require 'services/complete_moab_service/shared_examples'

RSpec.describe CompleteMoabService::Create do
  let(:druid) { 'ab123cd4567' }
  let(:incoming_version) { 6 }
  let(:incoming_size) { 9876 }
  let(:storage_dir) { 'spec/fixtures/storage_root01/sdr2objects' }
  let(:moab_storage_root) { MoabStorageRoot.find_by(storage_location: storage_dir) }
  let(:complete_moab_service) do
    described_class.new(druid: druid, incoming_version: incoming_version, incoming_size: incoming_size, moab_storage_root: moab_storage_root)
  end
  let(:expected_msg) { 'added object to db as it did not exist' }
  let(:audit_workflow_reporter) { instance_double(Reporters::AuditWorkflowReporter, report_errors: nil) }
  let(:logger_reporter) { instance_double(Reporters::LoggerReporter, report_errors: nil) }
  let(:honeybadger_reporter) { instance_double(Reporters::HoneybadgerReporter, report_errors: nil) }
  let(:event_service_reporter) { instance_double(Reporters::EventServiceReporter, report_errors: nil) }

  before do
    allow(Reporters::AuditWorkflowReporter).to receive(:new).and_return(audit_workflow_reporter)
    allow(Reporters::LoggerReporter).to receive(:new).and_return(logger_reporter)
    allow(Reporters::HoneybadgerReporter).to receive(:new).and_return(honeybadger_reporter)
    allow(Reporters::EventServiceReporter).to receive(:new).and_return(event_service_reporter)
  end

  describe '#execute' do
    it 'creates PreservedObject and CompleteMoab in database' do
      complete_moab_service.execute
      new_preserved_object = PreservedObject.find_by(druid: druid)
      new_complete_moab = new_preserved_object.complete_moab
      expect(new_preserved_object.current_version).to eq incoming_version
      expect(new_complete_moab.moab_storage_root).to eq moab_storage_root
      expect(new_complete_moab.size).to eq incoming_size
    end

    it 'creates the CompleteMoab with "ok" status and validation timestamps if caller ran CV' do
      complete_moab_service.execute(checksums_validated: true)
      new_complete_moab = complete_moab_service.preserved_object.complete_moab
      expect(new_complete_moab.status).to eq 'ok'
      expect(new_complete_moab.last_version_audit).to be_a ActiveSupport::TimeWithZone
      expect(new_complete_moab.last_moab_validation).to be_a ActiveSupport::TimeWithZone
      expect(new_complete_moab.last_checksum_validation).to be_a ActiveSupport::TimeWithZone
    end

    it_behaves_like 'attributes validated'

    it 'object already exists' do
      complete_moab_service.execute
      new_complete_moab_service = described_class.new(druid: druid, incoming_version: incoming_version, incoming_size: incoming_size,
                                                      moab_storage_root: moab_storage_root)
      audit_results = new_complete_moab_service.execute
      code = AuditResults::DB_OBJ_ALREADY_EXISTS
      expect(audit_results.results).to include(a_hash_including(code => a_string_matching('CompleteMoab db object already exists')))
    end

    it_behaves_like 'calls AuditResultsReporter.report_results'

    context 'db update error' do
      context 'ActiveRecordError' do
        before do
          allow(PreservedObject).to receive(:create!).with(hash_including(druid: druid))
                                                     .and_raise(ActiveRecord::ActiveRecordError, 'foo')
        end

        it 'DB_UPDATE_FAILED result' do
          expect(complete_moab_service.execute.results).to include(a_hash_including(AuditResults::DB_UPDATE_FAILED))
        end

        it 'does NOT get CREATED_NEW_OBJECT result' do
          expect(complete_moab_service.execute.results).not_to include(hash_including(AuditResults::CREATED_NEW_OBJECT))
        end
      end

      it "rolls back PreservedObject creation if the CompleteMoab can't be created (e.g. due to DB constraint violation)" do
        preserved_object = instance_double(PreservedObject)
        allow(PreservedObject).to receive(:create!).with(hash_including(druid: druid)).and_return(preserved_object)
        allow(preserved_object).to receive(:create_complete_moab!).and_raise(ActiveRecord::RecordInvalid)
        complete_moab_service.execute
        expect(PreservedObject.find_by(druid: druid)).to be_nil
      end
    end

    context 'returns' do
      let(:audit_result) { complete_moab_service.execute }

      it '1 result of CREATED_NEW_OBJECT' do
        expect(audit_result).to be_an_instance_of AuditResults
        expect(audit_result.results.size).to eq 1
        expect(audit_result.results.first).to match(a_hash_including(AuditResults::CREATED_NEW_OBJECT => expected_msg))
      end
    end
  end
end
