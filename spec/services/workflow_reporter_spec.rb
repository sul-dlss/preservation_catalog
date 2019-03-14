require 'rails_helper'

RSpec.describe WorkflowReporter do
  describe '.report_error' do
    it 'returns true' do
      # because we always get true the from the dor-workflow-service gem
      # see issue sul-dlss/dor-workflow-service#50 for more context
      full_url = 'https://workflows.example.org/workflow/dor/objects/druid:jj925bx9565/workflows/preservationAuditWF/moab-valid'
      result = 'Invalid moab, validation error...ential version directories.'
      body = "<?xml version=\"1.0\"?>\n<process name=\"moab-valid\" status=\"error\" errorMessage=\"#{result}\"/>\n"
      druid = 'jj925bx9565'
      process_name = 'moab-valid'

      stub_request(:put, full_url)
        .with(body: body)
        .to_return(status: 200, body: "", headers: {})

      expect(described_class.report_error(druid, process_name, result)).to be true
    end
  end

  describe '.report_completed' do
    it 'returns true' do
      full_url = 'https://workflows.example.org/workflow/dor/objects/druid:jj925bx9565/workflows/preservationAuditWF/preservation-audit'
      body = "<?xml version=\"1.0\"?>\n<process name=\"preservation-audit\" status=\"completed\" elapsed=\"0\"/>\n"
      druid = 'jj925bx9565'
      process_name = 'preservation-audit'

      stub_request(:put, full_url)
        .with(body: body)
        .to_return(status: 200, body: "", headers: {})

      expect(described_class.report_completed(druid, process_name)).to be true
    end
  end
end
