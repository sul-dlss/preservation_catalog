# frozen_string_literal: true

require 'rails_helper'
require 'services/moab_record_service/shared_examples'

RSpec.describe MoabRecordService::Create do
  let(:druid) { 'ab123cd4567' }
  let(:incoming_version) { 6 }
  let(:incoming_size) { 9876 }
  let(:storage_dir) { 'spec/fixtures/storage_root01/sdr2objects' }
  let(:moab_storage_root) { MoabStorageRoot.find_by(storage_location: storage_dir) }
  let(:moab_record_service) do
    described_class.new(druid: druid, incoming_version: incoming_version, incoming_size: incoming_size, moab_storage_root: moab_storage_root)
  end
  let(:expected_msg) { 'added object to db as it did not exist' }
  let(:audit_workflow_reporter) { instance_double(AuditReporters::AuditWorkflowReporter, report_errors: nil) }
  let(:logger_reporter) { instance_double(AuditReporters::LoggerReporter, report_errors: nil) }
  let(:honeybadger_reporter) { instance_double(AuditReporters::HoneybadgerReporter, report_errors: nil) }
  let(:event_service_reporter) { instance_double(AuditReporters::EventServiceReporter, report_errors: nil) }

  before do
    allow(AuditReporters::AuditWorkflowReporter).to receive(:new).and_return(audit_workflow_reporter)
    allow(AuditReporters::LoggerReporter).to receive(:new).and_return(logger_reporter)
    allow(AuditReporters::HoneybadgerReporter).to receive(:new).and_return(honeybadger_reporter)
    allow(AuditReporters::EventServiceReporter).to receive(:new).and_return(event_service_reporter)
  end

  describe '#execute' do
    it 'creates PreservedObject and MoabRecord in database' do
      moab_record_service.execute
      new_preserved_object = PreservedObject.find_by(druid: druid)
      new_moab_record = new_preserved_object.moab_record
      expect(new_preserved_object.current_version).to eq incoming_version
      expect(new_moab_record.moab_storage_root).to eq moab_storage_root
      expect(new_moab_record.size).to eq incoming_size
    end

    it 'creates the MoabRecord with "ok" status and validation timestamps if caller ran CV' do
      moab_record_service.execute(checksums_validated: true)
      new_moab_record = moab_record_service.preserved_object.moab_record
      expect(new_moab_record.status).to eq 'ok'
      expect(new_moab_record.last_version_audit).to be_a ActiveSupport::TimeWithZone
      expect(new_moab_record.last_moab_validation).to be_a ActiveSupport::TimeWithZone
      expect(new_moab_record.last_checksum_validation).to be_a ActiveSupport::TimeWithZone
    end

    it_behaves_like 'attributes validated'

    it 'object already exists' do
      moab_record_service.execute
      new_moab_record_service = described_class.new(druid: druid, incoming_version: incoming_version, incoming_size: incoming_size,
                                                    moab_storage_root: moab_storage_root)
      audit_results = new_moab_record_service.execute
      code = Audit::Results::DB_OBJ_ALREADY_EXISTS
      expect(audit_results.results).to include(a_hash_including(code => a_string_matching('MoabRecord db object already exists')))
    end

    it_behaves_like 'calls AuditResultsReporter.report_results'

    context 'db update error' do
      context 'ActiveRecordError' do
        before do
          allow(PreservedObject).to receive(:create!).with(hash_including(druid: druid))
                                                     .and_raise(ActiveRecord::ActiveRecordError, 'foo')
        end

        it 'DB_UPDATE_FAILED result' do
          expect(moab_record_service.execute.results).to include(a_hash_including(Audit::Results::DB_UPDATE_FAILED))
        end

        it 'does NOT get CREATED_NEW_OBJECT result' do
          expect(moab_record_service.execute.results).not_to include(hash_including(Audit::Results::CREATED_NEW_OBJECT))
        end
      end

      it "rolls back PreservedObject creation if the MoabRecord can't be created (e.g. due to DB constraint violation)" do
        preserved_object = instance_double(PreservedObject)
        allow(PreservedObject).to receive(:create!).with(hash_including(druid: druid)).and_return(preserved_object)
        allow(preserved_object).to receive(:create_moab_record!).and_raise(ActiveRecord::RecordInvalid)
        moab_record_service.execute
        expect(PreservedObject.find_by(druid: druid)).to be_nil
      end
    end

    context 'returns' do
      let(:audit_result) { moab_record_service.execute }

      it '1 result of CREATED_NEW_OBJECT' do
        expect(audit_result).to be_an_instance_of Audit::Results
        expect(audit_result.results.size).to eq 1
        expect(audit_result.results.first).to match(a_hash_including(Audit::Results::CREATED_NEW_OBJECT => expected_msg))
      end
    end
  end
end
