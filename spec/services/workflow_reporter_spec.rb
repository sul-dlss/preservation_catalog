require 'rails_helper'

RSpec.describe WorkflowReporter do
  let(:druid) { 'jj925bx9565' }

  describe '.report_error' do
    before do
      allow(Dor::Workflow::Client).to receive(:new).and_return(stub_client)
    end

    let(:stub_client) { instance_double(Dor::Workflow::Client, update_workflow_error_status: true) }

    let(:process_name) { 'moab-valid' }

    it 'returns true' do
      result = 'Invalid moab, validation error...ential version directories.'
      # because we always get true the from the dor-workflow-service gem
      # see issue sul-dlss/dor-workflow-client#50 for more context
      expect(described_class.report_error(druid, process_name, result)).to be true
      expect(stub_client).to have_received(:update_workflow_error_status).with('dor', "druid:#{druid}", 'preservationAuditWF', process_name, result)
    end
  end

  describe '.report_completed' do
    before do
      allow(Dor::Workflow::Client).to receive(:new).and_return(stub_client)
    end

    let(:stub_client) { instance_double(Dor::Workflow::Client, update_workflow_status: true) }
    let(:process_name) { 'preservation-audit' }

    it 'returns true' do
      expect(described_class.report_completed(druid, process_name)).to be true
      expect(stub_client).to have_received(:update_workflow_status).with('dor', "druid:#{druid}", 'preservationAuditWF', process_name, 'completed')
    end
  end
end
