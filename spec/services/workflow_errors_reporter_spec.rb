require 'rails_helper'

RSpec.describe WorkflowErrorsReporter do
  let(:full_url) do
    'https://sul-lyberservices-test.stanford.edu/workflow/dor/objects/druid:jj925bx9565/workflows/preservationAuditWF/moab-valid'
  end
  let(:headers) { { 'Content-Type' => 'application/xml' } }
  let(:result) do
    { 13 => "Invalid moab, validation error...ential version directories." }
  end
  let(:body) { "<process name='moab-valid' status='error' errorMessage='{13=>\"Invalid moab, validation error...ential version directories.\"}'/>" }
  let(:druid) { 'jj925bx9565' }

  context '.update_workflow' do
    it '204 response' do
      Settings.workflow_services_url = 'https://sul-lyberservices-test.stanford.edu/workflow/'
      stub_request(:put, full_url)
        .with(body: body,
              headers: headers)
        .to_return(status: 204, body: "", headers: {})
      expect(Rails.logger).to receive(:debug).with("#{druid} - sent error to workflow service for preservationAuditWF moab-valid")
      described_class.update_workflow(druid, 'moab-valid', result)
    end

    it '400 response' do
      Settings.workflow_services_url = 'https://sul-lyberservices-test.stanford.edu/workflow/'
      stub_request(:put, full_url)
        .with(body: body,
              headers: headers)
        .to_return(status: 400, body: "", headers: {})
      expect(Rails.logger).to receive(:warn).with("#{druid} - unable to update workflow for preservationAuditWF moab-valid #<Faraday::ClientError response={:status=>400, :headers=>{}, :body=>\"\"}>. Error message: #{result}")
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

    it 'make sure request get correct params' do
      process_name = 'moab-valid'
      error_msg = "Invalid moab, validation error...ential version directories."
      mock_request = instance_double(Faraday::Request)
      headers_hash = {}
      expect(mock_request).to receive(:headers).and_return(headers_hash)
      expect(mock_request).to receive(:url).with("/workflow/dor/objects/druid:#{druid}/workflows/preservationAuditWF/#{process_name}")
      expect(mock_request).to receive(:body=).with("<process name='#{process_name}' status='error' errorMessage='#{error_msg}'/>")
      described_class.send(:request_params, mock_request, druid, process_name, error_msg)
      expect(headers_hash).to eq("content-type" => "application/xml")
    end
  end
end
