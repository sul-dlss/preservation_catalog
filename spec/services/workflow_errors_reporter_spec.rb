require 'rails_helper'

RSpec.describe WorkflowErrorsReporter do
  context '.update_workflow' do
    it 'returns true' do
      # because we always get true the from the dor-workflow-service gem
      # see issue sul-dlss/dor-workflow-service#50 for more context
      full_url = 'https://workflows.example.org/workflow/dor/objects/druid:jj925bx9565/workflows/preservationAuditWF/moab-valid'
      result = 'Invalid moab, validation error...ential version directories.'
      body = "<?xml version=\"1.0\"?>\n<process name=\"moab-valid\" status=\"error\" errorMessage=\"#{result}\"/>\n"
      headers = { 'User-Agent' => 'Faraday v0.15.2' }
      druid = 'jj925bx9565'
      process_name = 'moab-valid'

      stub_request(:put, full_url)
        .with(
          body: body,
          headers: headers
        ).to_return(status: 200, body: "", headers: {})

      expect(described_class.update_workflow(druid, process_name, result)).to be true
    end
  end
end
