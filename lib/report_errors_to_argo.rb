class ReportErrorsToArgo
  WORKFLOW = 'preservationWF'.freeze
  WORKFLOW_DEF = <<-EOXML
    <workflow id="preservationWF">
         <process name="start" />
         <process name="moab-valid"  />
         <process name="M2C-check-exist" />
         <process name="C2M-check-exist" />
    </workflow>
    EOXML
  REPO = "dor".freeze

  def initialize(druid)
    @druid = druid
  end

  def send_errors(workflow_process, error_msg)
    unless Dor::WorkflowService.get_active_workflows(REPO,"druid:#{@druid}").include?(WORKFLOW)
      Dor::WorkflowService.create_workflow(REPO,"druid:#{@druid}", WORKFLOW, WORKFLOW_DEF)
    end
    Dor::WorkflowService.update_workflow_error_status(REPO, "druid:#{@druid}", WORKFLOW, workflow_process, error_msg)
  end
end

