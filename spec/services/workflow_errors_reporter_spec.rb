require 'rails_helper'

RSpec.describe WorkflowErrorsReporter do
  let(:full_url) do
    'https://sul-lyberservices-test.stanford.edu/workflow/dor/objects/druid:jj925bx9565/workflows/preservationWF/moab-valid'
  end
  let(:headers) { { 'Content-Type' => 'application/xml' } }
  let(:result) do
    { 13 => "Invalid moab, validation error...ential version directories." }
  end
  let(:body) { "<process name='moab-valid status='error' errorMessage='#{result}'/>" }
  let(:druid) { 'jj925bx9565' }

  context '.update_workflow' do
    it '204 response' do
      Settings.workflow_services_url = 'https://sul-lyberservices-test.stanford.edu/workflow/'
      stub_request(:put, full_url)
        .with(body: body, headers: headers)
        .to_return(status: 204, body: '', headers: {})
      expect(Rails.logger).to receive(:debug).with("#{druid} - sent error to workflow service for preservationWF moab-valid")
      described_class.update_workflow(druid, 'moab-valid', result)
    end

    it '400 response' do
      Settings.workflow_services_url = 'https://sul-lyberservices-test.stanford.edu/workflow/'
      stub_request(:put, full_url)
        .with(body: body, headers: headers)
        .to_return(status: 400, body: "", headers: {})
      expect(Rails.logger).to receive(:warn).with("#{druid} - unable to update workflow for preservationWF moab-valid #<Faraday::ClientError response={:status=>400, :headers=>{}, :body=>\"\"}>. Error message: #{result}")
      described_class.update_workflow(druid, 'moab-valid', result)
    end

    it 'has invalid workflow_services_url' do
      stub_request(:put, full_url)
        .with(body: body, headers: headers)
        .to_return(status: 400, body: "", headers: {})
      Settings.workflow_services_url = ''
      expect(Rails.logger).to receive(:warn).with('no workflow hookup - assume you are in test or dev environment')
      described_class.update_workflow(druid, 'moab-valid', result)
    end
  end
end
