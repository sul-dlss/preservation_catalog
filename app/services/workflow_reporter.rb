# frozen_string_literal: true

# send errors to preservationAuditWF workflow for an object via ReST calls.
class WorkflowReporter
  PRESERVATIONAUDITWF = 'preservationAuditWF'
  NO_WORKFLOW_HOOKUP = 'no workflow hookup - assume you are in test or dev environment'
  COMPLETED = 'completed'

  # this method will always return true because of the dor-workflow-service gem
  # see issue sul-dlss/dor-workflow-service#50 for more context
  def self.report_error(druid, process_name, error_message)
    if Settings.workflow_services_url.present?
      workflow_client.update_error_status(druid: "druid:#{druid}",
                                          workflow: PRESERVATIONAUDITWF,
                                          process: process_name,
                                          error_msg: error_message)
    else
      Rails.logger.warn(NO_WORKFLOW_HOOKUP)
    end
  end

  def self.report_completed(druid, process_name)
    if Settings.workflow_services_url.present?
      workflow_client.update_status(druid: "druid:#{druid}",
                                    workflow: PRESERVATIONAUDITWF,
                                    process: process_name,
                                    status: COMPLETED)
    else
      Rails.logger.warn(NO_WORKFLOW_HOOKUP)
    end
  end

  def self.workflow_client
    wf_log = Logger.new('log/workflow_service.log', 'weekly')
    Dor::Workflow::Client.new(
      url: Settings.workflow_services_url,
      logger: wf_log
    )
  end
  private_class_method :workflow_client
end
