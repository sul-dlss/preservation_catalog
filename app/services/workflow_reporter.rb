# send errors to preservationAuditWF workflow for an object via ReST calls.
class WorkflowReporter
  DOR = 'dor'.freeze
  PRESERVATIONAUDITWF = 'preservationAuditWF'.freeze
  NO_WORKFLOW_HOOKUP = 'no workflow hookup - assume you are in test or dev environment'.freeze
  COMPLETED = 'completed'.freeze

  # this method will always return true because of the dor-workflow-service gem
  # see issue sul-dlss/dor-workflow-service#50 for more context
  def self.report_error(druid, process_name, error_message)
    if Settings.workflow_services_url.present?
      Dor::WorkflowService.update_workflow_error_status(DOR, "druid:#{druid}", PRESERVATIONAUDITWF, process_name, error_message)
    else
      Rails.logger.warn(NO_WORKFLOW_HOOKUP)
    end
  end

  def self.report_completed(druid, process_name)
    if Settings.workflow_services_url.present?
      Dor::WorkflowService.update_workflow_status(DOR, "druid:#{druid}", PRESERVATIONAUDITWF, process_name, COMPLETED)
    else
      Rails.logger.warn(NO_WORKFLOW_HOOKUP)
    end
  end
end
