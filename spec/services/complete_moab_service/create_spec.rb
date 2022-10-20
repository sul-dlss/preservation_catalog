# frozen_string_literal: true

require 'rails_helper'
require 'services/complete_moab_service/shared_examples'

RSpec.describe CompleteMoabService::Create do
  let(:druid) { 'ab123cd4567' }
  let(:incoming_version) { 6 }
  let(:incoming_size) { 9876 }
  let(:storage_dir) { 'spec/fixtures/storage_root01/sdr2objects' }
  let(:ms_root) { MoabStorageRoot.find_by(storage_location: storage_dir) }
  let(:complete_moab_handler) do
    described_class.new(druid: druid, incoming_version: incoming_version, incoming_size: incoming_size, moab_storage_root: ms_root)
  end
  let(:exp_msg) { 'added object to db as it did not exist' }
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
    it 'creates PreservedObject and CompleteMoab and PreservedObjectsPrimaryMoab in database' do
      complete_moab_handler.execute
      new_po = PreservedObject.find_by(druid: druid)
      new_cm = new_po.complete_moab
      expect(new_po.current_version).to eq incoming_version
      expect(new_cm.moab_storage_root).to eq ms_root
      expect(new_cm.size).to eq incoming_size
      expect(new_po.preserved_objects_primary_moab.complete_moab_id).to eq new_cm.id
    end

    it 'creates the CompleteMoab with "ok" status and validation timestamps if caller ran CV' do
      complete_moab_handler.execute(checksums_validated: true)
      new_cm = complete_moab_handler.pres_object.complete_moab
      expect(new_cm.status).to eq 'ok'
      expect(new_cm.last_version_audit).to be_a ActiveSupport::TimeWithZone
      expect(new_cm.last_moab_validation).to be_a ActiveSupport::TimeWithZone
      expect(new_cm.last_checksum_validation).to be_a ActiveSupport::TimeWithZone
    end

    it_behaves_like 'attributes validated'

    it 'object already exists' do
      complete_moab_handler.execute
      new_complete_moab_handler = described_class.new(druid: druid, incoming_version: incoming_version, incoming_size: incoming_size,
                                                      moab_storage_root: ms_root)
      audit_results = new_complete_moab_handler.execute
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
          expect(complete_moab_handler.execute.results).to include(a_hash_including(AuditResults::DB_UPDATE_FAILED))
        end

        it 'does NOT get CREATED_NEW_OBJECT result' do
          expect(complete_moab_handler.execute.results).not_to include(hash_including(AuditResults::CREATED_NEW_OBJECT))
        end
      end

      it "rolls back PreservedObject creation if the CompleteMoab can't be created (e.g. due to DB constraint violation)" do
        po = instance_double(PreservedObject)
        allow(PreservedObject).to receive(:create!).with(hash_including(druid: druid)).and_return(po)
        allow(po).to receive(:create_complete_moab!).and_raise(ActiveRecord::RecordInvalid)
        complete_moab_handler.execute
        expect(PreservedObject.find_by(druid: druid)).to be_nil
      end
    end

    context 'returns' do
      let(:audit_result) { complete_moab_handler.execute }

      it '1 result of CREATED_NEW_OBJECT' do
        expect(audit_result).to be_an_instance_of AuditResults
        expect(audit_result.results.size).to eq 1
        expect(audit_result.results.first).to match(a_hash_including(AuditResults::CREATED_NEW_OBJECT => exp_msg))
      end
    end
  end
end
