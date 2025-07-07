# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuditReporters::AuditWorkflowReporter do
  let(:client) { instance_double(Dor::Services::Client::Object, workflow: object_workflow) }
  let(:object_workflow) { instance_double(Dor::Services::Client::ObjectWorkflow, process:) }
  let(:process) { instance_double(Dor::Services::Client::Process, update: true, update_error: true) }
  let(:druid) { 'ab123cd4567' }
  let(:actual_version) { 6 }
  let(:ms_root) { MoabStorageRoot.find_by(storage_location: 'spec/fixtures/storage_root01/sdr2objects') }
  let(:check_name) { 'FooCheck' }

  before do
    allow(Dor::Services::Client).to receive(:object).with("druid:#{druid}").and_return(client)
  end

  describe '#report_errors' do
    context 'when INVALID_MOAB' do
      let(:result1) do
        {
          Audit::Results::INVALID_MOAB =>
                            "Invalid Moab, validation errors: [Version directory name not in 'v00xx' format: original-v1]"
        }
      end
      let(:result2) do
        {
          Audit::Results::INVALID_MOAB =>
                          "Invalid Moab, validation errors: [Version directory name not in 'v00xx' format: original-v2]"
        }
      end

      it 'updates workflow for each error' do
        described_class.new.report_errors(druid: druid,
                                          version: actual_version,
                                          storage_area: ms_root,
                                          check_name: check_name,
                                          results: [result1, result2])
        error_msg1 = 'FooCheck (actual location: fixture_sr1; actual version: 6) || Invalid Moab, validation errors: ' \
                     "[Version directory name not in 'v00xx' format: original-v1]"
        expect(process).to have_received(:update_error).with(error_msg: error_msg1)
        error_msg2 = 'FooCheck (actual location: fixture_sr1; actual version: 6) || Invalid Moab, validation errors: ' \
                     "[Version directory name not in 'v00xx' format: original-v2]"
        expect(process).to have_received(:update_error).with(error_msg: error_msg2)
      end
    end

    context 'when other errors' do
      let(:result1) { { Audit::Results::DB_VERSIONS_DISAGREE => 'does not match PreservedObject current_version' } }
      let(:result2) { { Audit::Results::UNEXPECTED_VERSION => 'actual version (6) has unexpected relationship to db version' } }

      it 'merges errors and updates workflow' do
        described_class.new.report_errors(druid: druid,
                                          version: actual_version,
                                          storage_area: ms_root,
                                          check_name: check_name,
                                          results: [result1, result2])
        error_msg = 'FooCheck (actual location: fixture_sr1; actual version: 6) does not match PreservedObject current_version ' \
                    '&& actual version (6) has unexpected relationship to db version'
        expect(process).to have_received(:update_error).with(error_msg: error_msg)
      end
    end

    context 'when workflow does not exist' do
      let(:result) { { Audit::Results::DB_VERSIONS_DISAGREE => 'does not match PreservedObject current_version' } }

      before do
        call_count = 0
        allow(process).to receive(:update_error) do
          call_count += 1
          call_count == 1 ? raise(Dor::Services::Client::NotFoundResponse) : nil
        end
        allow(object_workflow).to receive(:create)
      end

      it 'creates the workflow and retries' do
        described_class.new.report_errors(druid: druid, version: actual_version, storage_area: ms_root, check_name: check_name, results: [result])
        error_msg = 'FooCheck (actual location: fixture_sr1; actual version: 6) does not match PreservedObject current_version'
        expect(process).to have_received(:update_error).with(error_msg: error_msg).twice
        expect(object_workflow).to have_received(:create).with(version: 6)
      end
    end

    context 'when ignored error' do
      let(:result) { { Audit::Results::ZIP_PARTS_NOT_CREATED => 'no zip_parts exist yet for this ZippedMoabVersion' } }

      it 'does not update workflow' do
        described_class.new.report_errors(druid: druid, version: actual_version, storage_area: ms_root, check_name: check_name, results: [result])
        expect(process).not_to have_received(:update_error)
      end
    end
  end

  describe '#report_completed' do
    let(:result) { { Audit::Results::MOAB_RECORD_STATUS_CHANGED => 'MoabRecord status changed from invalid_moab' } }

    it 'updates workflow' do
      described_class.new.report_completed(druid: druid, version: actual_version, storage_area: ms_root, check_name: check_name, result: result)

      expect(process).to have_received(:update).with(status: 'completed').twice
    end

    context 'when workflow does not exist' do
      before do
        call_count = 0
        allow(process).to receive(:update) do
          call_count += 1
          call_count == 1 ? raise(Dor::Services::Client::NotFoundResponse) : nil
        end
        allow(object_workflow).to receive(:create)
      end

      it 'creates the workflow and retries' do
        described_class.new.report_completed(druid: druid, version: actual_version, storage_area: ms_root, check_name: check_name, result: result)

        expect(process).to have_received(:update).with(status: 'completed').exactly(3).times
        expect(object_workflow).to have_received(:create).with(version: 6)
      end
    end
  end
end
