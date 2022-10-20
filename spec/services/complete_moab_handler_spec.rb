# frozen_string_literal: true

require 'rails_helper'
require 'services/shared_examples_complete_moab_handler'

RSpec.describe CompleteMoabHandler do
  let(:audit_workflow_reporter) { instance_double(Reporters::AuditWorkflowReporter, report_errors: nil) }
  let(:druid) { 'ab123cd4567' }
  let(:incoming_version) { 6 }
  let(:incoming_size) { 9876 }
  let!(:default_prez_policy) { PreservationPolicy.default_policy }
  let(:po) { PreservedObject.find_by(druid: druid) }
  let(:ms_root) { MoabStorageRoot.find_by(storage_location: 'spec/fixtures/storage_root01/sdr2objects') }
  let(:cm) { CompleteMoab.find_by(preserved_object: po, moab_storage_root: ms_root) }
  let(:complete_moab_handler) { described_class.new(druid, incoming_version, incoming_size, ms_root) }
  let(:logger_reporter) { instance_double(Reporters::LoggerReporter, report_errors: nil) }
  let(:honeybadger_reporter) { instance_double(Reporters::HoneybadgerReporter, report_errors: nil) }
  let(:event_service_reporter) { instance_double(Reporters::EventServiceReporter, report_errors: nil) }

  before do
    allow(Reporters::AuditWorkflowReporter).to receive(:new).and_return(audit_workflow_reporter)
    allow(Reporters::LoggerReporter).to receive(:new).and_return(logger_reporter)
    allow(Reporters::HoneybadgerReporter).to receive(:new).and_return(honeybadger_reporter)
    allow(Reporters::EventServiceReporter).to receive(:new).and_return(event_service_reporter)
  end

  describe '#with_active_record_transaction_and_rescue' do
    it '#confirm_version rolls back preserved object if there is a problem updating complete moab' do
      po = PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy)
      cm = CompleteMoab.create!(
        preserved_object: po,
        version: po.current_version,
        size: 1,
        moab_storage_root: ms_root,
        status: 'validity_unknown'
      )
      bad_complete_moab_handler = described_class.new(druid, 6, incoming_size, ms_root)
      allow(cm).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError)
      # have to get the #moab_validator instance, because allow won't intercept the delegated CMH#moab_validation_errors
      allow(bad_complete_moab_handler.send(:moab_validator)).to receive(:moab_validation_errors).and_return([])
      bad_complete_moab_handler.confirm_version
      expect(PreservedObject.find_by(druid: druid).current_version).to eq 2
    end

    context 'ActiveRecordError gives DB_UPDATE_FAILED error with rich details' do
      let(:result_code) { AuditResults::DB_UPDATE_FAILED }
      let(:results) do
        allow(PreservedObject).to receive(:create!).with(hash_including(druid: druid))
                                                   .and_raise(ActiveRecord::ActiveRecordError, 'specific_err_msg')
        complete_moab_handler.create
      end

      it 'specific exception raised' do
        expect(results).to include(a_hash_including(result_code => a_string_matching('ActiveRecord::ActiveRecordError')))
      end

      it "exception's message" do
        expect(results).to include(a_hash_including(result_code => a_string_matching('specific_err_msg')))
      end
    end
  end

  describe '#moab_validation_errors' do
    it 'calls validator.validator_errors with moab.allow_content_subdirs from Settings.yml' do
      sov = instance_double(Moab::StorageObjectValidator)
      allow(Moab::StorageObjectValidator).to receive(:new).and_return(sov)
      expect(sov).to receive(:validation_errors).with(true).and_return([])
      complete_moab_handler.create_after_validation
    end
  end

  describe 'MoabStorageRoot validation' do
    it 'errors when moab_storage_root is not an MoabStorageRoot object' do
      complete_moab_handler = described_class.new(druid, incoming_version, incoming_size, 1)
      expect(complete_moab_handler).to be_invalid
      expect(complete_moab_handler.errors.messages).to match(hash_including(moab_storage_root: ['must be an actual MoabStorageRoot']))
    end
  end
end
