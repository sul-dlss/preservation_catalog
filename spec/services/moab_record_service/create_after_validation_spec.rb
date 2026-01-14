# frozen_string_literal: true

require 'rails_helper'
require 'services/moab_record_service/shared_examples'

RSpec.describe MoabRecordService::CreateAfterValidation do
  let(:druid) { 'ab123cd4567' }
  let(:incoming_version) { 6 }
  let(:incoming_size) { 9876 }
  let(:storage_dir) { 'spec/fixtures/storage_root01/sdr2objects' }
  let(:moab_storage_root) { MoabStorageRoot.find_by(storage_location: storage_dir) }
  let(:expected_msg) { 'added object to db as it did not exist' }
  let(:audit_workflow_reporter) { instance_double(ResultsReporters::AuditWorkflowReporter, report_errors: nil) }
  let(:logger_reporter) { instance_double(ResultsReporters::LoggerReporter, report_errors: nil) }
  let(:honeybadger_reporter) { instance_double(ResultsReporters::HoneybadgerReporter, report_errors: nil) }
  let(:event_service_reporter) { instance_double(ResultsReporters::EventServiceReporter, report_errors: nil) }

  before do
    allow(ResultsReporters::AuditWorkflowReporter).to receive(:new).and_return(audit_workflow_reporter)
    allow(ResultsReporters::LoggerReporter).to receive(:new).and_return(logger_reporter)
    allow(ResultsReporters::HoneybadgerReporter).to receive(:new).and_return(honeybadger_reporter)
    allow(ResultsReporters::EventServiceReporter).to receive(:new).and_return(event_service_reporter)
  end

  describe '#execute' do
    let(:valid_druid) { 'bp628nk4868' }
    let(:storage_dir) { 'spec/fixtures/storage_root02/sdr2objects' }
    let(:moab_record_service) do
      described_class.new(druid: valid_druid, incoming_version: incoming_version, incoming_size: incoming_size, moab_storage_root: moab_storage_root)
    end

    it_behaves_like 'attributes validated'

    it_behaves_like 'calls AuditResultsReporter.report_results'

    context 'sets validation timestamps' do
      let(:t) { Time.current }
      let(:moab_storage_root) { MoabStorageRoot.find_by(storage_location: storage_dir) }
      let(:moab_record) { moab_record_service.preserved_object.moab_record }

      before { moab_record_service.execute }

      it 'sets last_moab_validation with current time' do
        expect(moab_record.last_moab_validation).to be_within(10).of(t)
      end

      it 'sets last_version_audit with current time' do
        expect(moab_record.last_version_audit).to be_within(10).of(t)
      end
    end

    it 'creates PreservedObject and MoabRecord in database when there are no validation errors' do
      moab_record_service = described_class.new(druid: valid_druid, incoming_version: incoming_version, incoming_size: incoming_size,
                                                moab_storage_root: moab_storage_root)
      moab_record_service.execute
      new_preserved_object = PreservedObject.find_by(druid: valid_druid, current_version: incoming_version)
      expect(new_preserved_object).not_to be_nil
      new_moab_record = new_preserved_object.moab_record
      expect(new_moab_record).not_to be_nil
      expect(new_moab_record.status).to eq 'validity_unknown'
    end

    it 'creates MoabRecord with "ok" status and validation timestamps if no validation errors and caller ran CV' do
      moab_record_service = described_class.new(druid: valid_druid, incoming_version: incoming_version, incoming_size: incoming_size,
                                                moab_storage_root: moab_storage_root)
      moab_record_service.execute(checksums_validated: true)
      new_preserved_object = PreservedObject.find_by(druid: valid_druid, current_version: incoming_version)
      expect(new_preserved_object).not_to be_nil
      new_moab_record = new_preserved_object.moab_record
      expect(new_moab_record).not_to be_nil
      expect(new_moab_record.status).to eq 'ok'
      expect(new_moab_record.last_checksum_validation).to be_an ActiveSupport::TimeWithZone
    end

    it 'calls moab-versioning Stanford::StorageObjectValidator.validation_errors' do
      storage_object_validator = instance_double(Stanford::StorageObjectValidator)
      expect(storage_object_validator).to receive(:validation_errors).and_return([])
      allow(Stanford::StorageObjectValidator).to receive(:new).and_return(storage_object_validator)
      moab_record_service = described_class.new(druid: valid_druid, incoming_version: incoming_version, incoming_size: incoming_size,
                                                moab_storage_root: moab_storage_root)
      moab_record_service.execute
    end

    context 'when moab is invalid' do
      let(:storage_dir) { 'spec/fixtures/bad_root01/bad_moab_storage_trunk' }
      let(:moab_storage_root) { MoabStorageRoot.find_by(storage_location: storage_dir) }
      let(:invalid_druid) { 'xx000xx0000' }
      let(:moab_record_service) do
        described_class.new(druid: invalid_druid, incoming_version: incoming_version, incoming_size: incoming_size,
                            moab_storage_root: moab_storage_root)
      end

      # add storage root with invalid moab to the MoabStorageRoots table
      before do
        MoabStorageRoot.find_or_create_by!(name: 'bad_fixture_dir') do |moab_storage_root|
          moab_storage_root.storage_location = storage_dir
        end
      end

      it 'creates PreservedObject, and MoabRecord with "invalid_moab" status in database' do
        moab_record_service.execute
        new_preserved_object = PreservedObject.find_by(druid: invalid_druid, current_version: incoming_version)
        expect(new_preserved_object).not_to be_nil
        new_moab_record = new_preserved_object.moab_record
        expect(new_moab_record).not_to be_nil
        expect(new_moab_record.status).to eq 'invalid_moab'
        expect(new_moab_record.last_moab_validation).to be_a ActiveSupport::TimeWithZone
        expect(new_moab_record.last_version_audit).to be_a ActiveSupport::TimeWithZone
      end

      it 'creates MoabRecord with "invalid_moab" status in database even if caller ran CV' do
        moab_record_service.execute(checksums_validated: true)
        new_preserved_object = PreservedObject.find_by(druid: invalid_druid, current_version: incoming_version)
        expect(new_preserved_object).not_to be_nil
        new_moab_record = new_preserved_object.moab_record
        expect(new_moab_record).not_to be_nil
        expect(new_moab_record.status).to eq 'invalid_moab'
      end

      it 'includes invalid moab result' do
        results = moab_record_service.execute.results
        expect(results).to include(a_hash_including(Audit::Results::INVALID_MOAB => /Invalid Moab, validation errors:/))
      end

      context 'db update error' do
        context 'ActiveRecordError' do
          before do
            allow(PreservedObject).to receive(:create!).with(hash_including(druid: invalid_druid))
                                                       .and_raise(ActiveRecord::ActiveRecordError, 'foo')
            allow(ReplicationJob).to receive(:perform_later)
          end

          let(:results) do
            moab_record_service = described_class.new(druid: invalid_druid, incoming_version: incoming_version, incoming_size: incoming_size,
                                                      moab_storage_root: moab_storage_root)
            moab_record_service.execute.results
          end

          it 'DB_UPDATE_FAILED result' do
            expect(results).to include(a_hash_including(Audit::Results::DB_UPDATE_FAILED))
          end

          it 'does NOT get CREATED_NEW_OBJECT result' do
            expect(results).not_to include(hash_including(Audit::Results::CREATED_NEW_OBJECT))
          end

          it 'does not call ReplicationJob' do
            expect(ReplicationJob).not_to have_received(:perform_later)
          end
        end

        it "rolls back PreservedObject creation if the MoabRecord can't be created (e.g. due to DB constraint violation)" do
          allow(MoabRecord).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
          moab_record_service = described_class.new(druid: invalid_druid, incoming_version: incoming_version, incoming_size: incoming_size,
                                                    moab_storage_root: moab_storage_root)
          moab_record_service.execute
          expect(PreservedObject.where(druid: druid)).not_to exist
        end
      end
    end

    context 'returns' do
      let(:audit_result) { moab_record_service.execute }
      let(:results) { audit_result.results }

      it '1 CREATED_NEW_OBJECT result' do
        expect(audit_result).to be_an_instance_of Audit::Results
        expect(results.size).to eq 1
        expect(results.first).to include(Audit::Results::CREATED_NEW_OBJECT => expected_msg)
      end
    end
  end
end
