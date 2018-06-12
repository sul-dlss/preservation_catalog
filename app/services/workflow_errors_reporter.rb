
# send errors to preservationAuditWF workflow for an object via ReST calls.
class WorkflowErrorsReporter

  # this method will always return true because of the dor-workflow-service gem
  # see issue sul-dlss/dor-workflow-service#50 for more context
  def self.update_workflow(druid, process_name, error_message)
    if Settings.workflow_services_url.present?
      Dor::WorkflowService.update_workflow_error_status('dor', "druid:#{druid}", 'preservationAuditWF', process_name, error_message)
    else
      Rails.logger.warn('no workflow hookup - assume you are in test or dev environment')
    end
  end

  def self.complete_workflow(druid, process_name)
    if Settings.workflow_services_url.present?
      Dor::WorkflowService.update_workflow_status('dor', "druid:#{druid}", 'preservationAuditWF', process_name, 'completed')
    else
      Rails.logger.warn('no workflow hookup - assume you are in test or dev environment')
    end
  end
end
