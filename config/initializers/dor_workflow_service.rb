require 'dor-workflow-service'
wf_log = Logger.new('log/workflow_service.log', 'weekly')
Dor::WorkflowService.configure(
  Settings.workflow_services_url,
  logger: wf_log
)
