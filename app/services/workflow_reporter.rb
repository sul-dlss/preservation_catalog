# frozen_string_literal: true

# send errors to preservationAuditWF workflow for an object via ReST calls.
# NOTE: this approach allows online Moab audit errors to block further accessioning (which is desired)
#   - any WF error blocks further accessioning (i.e. can't open a new version)
#   - we currently only send WF errors from audits of online moabs (replication audit problems don't show up in WF)
class WorkflowReporter
  PRESERVATIONAUDITWF = 'preservationAuditWF'
  NO_WORKFLOW_HOOKUP = 'no workflow hookup - assume you are in test or dev environment'
  COMPLETED = 'completed'

  # this method will always return true because of the dor-workflow-service gem
  # see issue sul-dlss/dor-workflow-service#50 for more context
  def self.report_error(druid, version, process_name, error_message)
    if Settings.workflow_services_url.present?
      workflow_client.update_error_status(druid: "druid:#{druid}",
                                          workflow: PRESERVATIONAUDITWF,
                                          process: process_name,
                                          error_msg: error_message)
    else
      Rails.logger.warn(NO_WORKFLOW_HOOKUP)
    end
  rescue Dor::MissingWorkflowException
    create_wf(druid, version)
    report_error(druid, version, process_name, error_message)
  end

  def self.report_completed(druid, version, process_name)
    if Settings.workflow_services_url.present?
      workflow_client.update_status(druid: "druid:#{druid}",
                                    workflow: PRESERVATIONAUDITWF,
                                    process: process_name,
                                    status: COMPLETED)
    else
      Rails.logger.warn(NO_WORKFLOW_HOOKUP)
    end
  rescue Dor::MissingWorkflowException
    create_wf(druid, version)
    report_completed(druid, version, process_name)
  end

  def self.create_wf(druid, version)
    namespaced_druid = druid.start_with?('druid:') ? druid : "druid:#{druid}"
    workflow_client.create_workflow_by_name(namespaced_druid, PRESERVATIONAUDITWF, version: version)
  end
  private_class_method :create_wf

  def self.workflow_client
    wf_log = Logger.new('log/workflow_service.log', 'weekly')
    Dor::Workflow::Client.new(
      url: Settings.workflow_services_url,
      logger: wf_log
    )
  end
  private_class_method :workflow_client
end
