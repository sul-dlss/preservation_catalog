# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkflowReporter do
  subject(:reporter) do
    described_class.new(
      druid: druid,
      version: version,
      process_name: process_name,
      moab_storage_root: storage_root,
      error_message: error_message
    )
  end

  let(:druid) { 'jj925bx9565' }
  let(:error_message) { "Failed to retrieve response #{Settings.workflow_services_url}/preservationAuditWF/something (HTTP status 404)" }
  let(:events_client) { instance_double(Dor::Services::Client::Events, create: nil) }
  let(:process_name) { 'preservation-audit' }
  let(:storage_root) { MoabStorageRoot.first }
  let(:stub_wf_client) { instance_double(Dor::Workflow::Client, create_workflow_by_name: nil) }
  let(:version) { '1' }
  let(:wf_server_response_json) { { some: 'json response from wf server' } }

  before do
    allow(Dor::Workflow::Client).to receive(:new).and_return(stub_wf_client)
    allow(Socket).to receive(:gethostname).and_return('fakehost')
    allow(Dor::Services::Client).to receive(:object).with("druid:#{druid}").and_return(
      instance_double(Dor::Services::Client::Object, events: events_client)
    )
  end

  # rubocop:disable RSpec/SubjectStub
  describe '.report_completed' do
    before do
      allow(described_class).to receive(:new)
        .with(druid: druid, version: version, process_name: process_name, moab_storage_root: storage_root)
        .and_return(reporter)
      allow(reporter).to receive(:report_completed)
    end

    it 'invokes #report_completed on a new instance' do
      described_class.report_completed(druid, version, process_name, storage_root)
      expect(reporter).to have_received(:report_completed).once
    end
  end

  describe '.report_error' do
    before do
      allow(described_class).to receive(:new)
        .with(druid: druid, version: version, process_name: process_name, moab_storage_root: storage_root, error_message: 'uh oh, something broke')
        .and_return(reporter)
      allow(reporter).to receive(:report_error)
    end

    it 'invokes #report_error on a new instance' do
      described_class.report_error(druid, version, process_name, storage_root, 'uh oh, something broke')
      expect(reporter).to have_received(:report_error).once
    end
  end

  describe '#create_workflow' do
    context 'when passed a bare druid' do
      it 'adds a namespace to the druid and sends it to the workflow client' do
        reporter.send(:create_workflow)

        expect(stub_wf_client).to have_received(:create_workflow_by_name)
          .once
          .with("druid:#{druid}", described_class::PRESERVATIONAUDITWF, version: version)
      end
    end
  end

  describe '#report_error' do
    let(:process_name) { 'moab-valid' }
    let(:error_message) { 'Invalid moab, validation error...ential version directories.' }

    context 'when workflow already exists' do
      let(:stub_wf_client) { instance_double(Dor::Workflow::Client, update_error_status: wf_server_response_json) }

      it 'returns json response from wf server (mocked here)' do
        expect(reporter.report_error).to eq wf_server_response_json
        expect(stub_wf_client).to have_received(:update_error_status)
          .with(druid: "druid:#{druid}",
                workflow: 'preservationAuditWF',
                process: process_name,
                error_msg: error_message)
        expect(Dor::Services::Client).to have_received(:object).with("druid:#{druid}").once
        expect(events_client).to have_received(:create).once.with(
          type: 'preservation_audit_failure',
          data: {
            host: 'fakehost',
            invoked_by: 'preservation-catalog',
            storage_root: storage_root.name,
            actual_version: version,
            check_name: process_name,
            error: error_message
          }
        )
      end
    end

    context 'when workflow does not exist' do
      let(:stub_wf_client) { instance_double(Dor::Workflow::Client) }

      before do
        allow(reporter).to receive(:create_workflow)
        allow(reporter).to receive(:report_error).and_call_original
        # AFAICT, this is how one gets RSpec to vary behavior on subsequent
        # calls that raise and return
        call_count = 0
        allow(stub_wf_client).to receive(:update_error_status) do
          call_count += 1
          call_count == 1 ? raise(Dor::MissingWorkflowException, error_message) : nil
        end
      end

      it 'creates workflow and calls report_error again' do
        reporter.report_error

        expect(reporter).to have_received(:create_workflow).once
        expect(Dor::Services::Client).to have_received(:object).with("druid:#{druid}").once
        expect(events_client).to have_received(:create).once
        expect(reporter).to have_received(:report_error).twice
      end
    end
  end

  describe '#report_completed' do
    context 'when workflow exists' do
      let(:stub_wf_client) { instance_double(Dor::Workflow::Client, update_status: wf_server_response_json) }

      it 'returns json response from wf server (mocked here)' do
        expect(reporter.report_completed).to eq wf_server_response_json
        expect(stub_wf_client).to have_received(:update_status)
          .with(druid: "druid:#{druid}",
                workflow: 'preservationAuditWF',
                process: process_name,
                status: 'completed')
        expect(Dor::Services::Client).to have_received(:object).with("druid:#{druid}").once
        expect(events_client).to have_received(:create).once.with(
          type: 'preservation_audit_success',
          data: {
            host: 'fakehost',
            invoked_by: 'preservation-catalog',
            storage_root: storage_root.name,
            actual_version: version,
            check_name: process_name
          }
        )
      end
    end

    context 'when workflow does not exist' do
      let(:stub_wf_client) { instance_double(Dor::Workflow::Client) }

      before do
        allow(reporter).to receive(:create_workflow)
        allow(reporter).to receive(:report_completed).and_call_original
        # AFAICT, this is how one gets RSpec to vary behavior on subsequent
        # calls that raise and return
        call_count = 0
        allow(stub_wf_client).to receive(:update_status) do
          call_count += 1
          call_count == 1 ? raise(Dor::MissingWorkflowException, error_message) : nil
        end
      end

      it 'creates workflow and calls report_completed again' do
        reporter.report_completed

        expect(reporter).to have_received(:create_workflow).once
        expect(Dor::Services::Client).to have_received(:object).with("druid:#{druid}").once
        expect(events_client).to have_received(:create).once
        expect(reporter).to have_received(:report_completed).twice
      end
    end
  end
  # rubocop:enable RSpec/SubjectStub
end
