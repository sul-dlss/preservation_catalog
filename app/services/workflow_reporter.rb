# frozen_string_literal: true

# send errors to preservationAuditWF workflow for an object via ReST calls.
# NOTE: this approach allows online Moab audit errors to block further accessioning (which is desired)
#   - any WF error blocks further accessioning (i.e. can't open a new version)
#   - we currently only send WF errors from audits of online moabs (replication audit problems don't show up in WF)
class WorkflowReporter
  PRESERVATIONAUDITWF = 'preservationAuditWF'
  NO_WORKFLOW_HOOKUP = 'no workflow hookup - assume you are in test or dev environment'
  COMPLETED = 'completed'

  def self.report_error(druid, version, process_name, moab_storage_root, error_message)
    new(druid: druid,
        version: version,
        process_name: process_name,
        moab_storage_root: moab_storage_root,
        error_message: error_message)
      .report_error
  end

  def self.report_completed(druid, version, process_name, moab_storage_root)
    new(druid: druid,
        version: version,
        process_name: process_name,
        moab_storage_root: moab_storage_root)
      .report_completed
  end

  def initialize(druid:, version:, process_name:, moab_storage_root:, error_message: nil)
    @druid = druid
    @version = version
    @process_name = process_name
    @moab_storage_root_name = moab_storage_root&.name
    @error_message = error_message
  end

  def report_error
    if Settings.workflow_services_url.present?
      workflow_result = workflow_client.update_error_status(druid: namespaced_druid,
                                                            workflow: PRESERVATIONAUDITWF,
                                                            process: process_name,
                                                            error_msg: error_message)
      create_failure_event
      workflow_result
    else
      Rails.logger.warn(NO_WORKFLOW_HOOKUP)
    end
  rescue Dor::MissingWorkflowException
    create_workflow
    report_error
  end

  def report_completed
    if Settings.workflow_services_url.present?
      workflow_result = workflow_client.update_status(druid: namespaced_druid,
                                                      workflow: PRESERVATIONAUDITWF,
                                                      process: process_name,
                                                      status: COMPLETED)
      create_success_event
      workflow_result
    else
      Rails.logger.warn(NO_WORKFLOW_HOOKUP)
    end
  rescue Dor::MissingWorkflowException
    create_workflow
    report_completed
  end

  private

  attr_reader :druid, :version, :process_name, :error_message, :moab_storage_root_name

  def create_failure_event
    events_client.create(
      type: 'preservation_audit_failure',
      data: {
        host: Socket.gethostname,
        invoked_by: 'preservation-catalog',
        storage_root: moab_storage_root_name,
        actual_version: version,
        check_name: process_name,
        error: error_message
      }
    )
  end

  def create_success_event
    events_client.create(
      type: 'preservation_audit_success',
      data: {
        host: Socket.gethostname,
        invoked_by: 'preservation-catalog',
        storage_root: moab_storage_root_name,
        actual_version: version,
        check_name: process_name
      }
    )
  end

  def events_client
    Dor::Services::Client.object(namespaced_druid).events
  end

  def create_workflow
    workflow_client.create_workflow_by_name(namespaced_druid, PRESERVATIONAUDITWF, version: version)
  end

  # prefixes the bare druid with the namespace, since dor-services-app and workflow server both
  # want the namespaced version
  def namespaced_druid
    "druid:#{druid}"
  end

  def workflow_client
    wf_log = Logger.new('log/workflow_service.log', 'weekly')
    Dor::Workflow::Client.new(
      url: Settings.workflow_services_url,
      logger: wf_log
    )
  end
end
