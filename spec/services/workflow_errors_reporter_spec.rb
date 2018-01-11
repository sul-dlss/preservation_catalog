require 'rails_helper'

RSpec.describe WorkflowErrorsReporter do
  describe '.update_workflow(druid, error_message)' do
    let(:body) { "<process name='moab-valid' status='error' errorMessage=' Invalid moab, validation errors: [\"Should contain only sequential version directories. Current directories: [\\\"v0001\\\", \\\"v0002\\\", \\\"v0009\\\"]\"]'/>" }
    let(:error_msg) do
      [{ 10 => "PreservedObjectHandler(jj925bx9565, 9, 6570668, <Endpoint:...>) PreservedObject db object does not exist" },
       { 13 => "PreservedObjectHandler(jj925bx9565, 9, 6570668, <Endpoint:...>) Invalid moab, validation errors: [\"Should contain only sequential version directories. Current directories: [\\\"v0001\\\", \\\"v0002\\\", \\\"v0009\\\"]\"]" }]
    end

    before do
      Settings.workflow_services.url = 'https://sul-lyberservices-test.stanford.edu/workflow/'
      stub_request(:put, 'https://sul-lyberservices-test.stanford.edu/workflow/dor/objects/druid:jj925bx9565/workflows/preservationWF/moab-valid')
        .with(body: body,
              headers: { 'Content-Type' => 'application/xml' })
        .to_return(status: 204, body: "", headers: {})
    end
    it 'updates preservationWF with invalid moab errors' do
      expect(described_class.update_workflow('jj925bx9565', error_msg)).to eq [error_msg[1]]
    end
  end
  describe '.request' do
    it 'rescues for Faraday::Error' do
      allow(described_class).to receive(:request).and_raise(Faraday::Error)
      expect { described_class.request('jj925bx9565', 'moab-valid', 'Foo() error') }.to raise_error(Faraday::Error)
    end
  end

  describe '.update_workflow with invalid workflow_services.url' do
    before do
      stub_request(:put, "https://sul-lyberservices-test.stanford.edu/workflow/dor/objects/druid:jj925bx9565/workflows/preservationWF/moab-valid")
        .with(body: "<process name='moab-valid' status='error' errorMessage=' Invalid Moab'/>",
              headers: { 'Content-Type' => 'application/xml' })
        .to_return(status: 200, body: "", headers: {})
    end
    it 'returns Rails warning' do
      Settings.workflow_services.url = ''
      expect(Rails.logger).to receive(:warn).with('no workflow hookup - assume you are in test or dev environment')
      described_class.update_workflow('jj925bx9565', [{ 13 => "Foo() Invalid Moab" }])
    end
  end
end
