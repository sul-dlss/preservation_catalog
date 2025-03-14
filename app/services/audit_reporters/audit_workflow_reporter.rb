# frozen_string_literal: true

module AuditReporters
  # Reports to DOR Workflow Service.
  class AuditWorkflowReporter < BaseReporter
    private

    def handled_single_codes
      [
        Audit::Results::INVALID_MOAB
      ]
    end

    # We only want codes pertaining to local moabs reported to the audit
    # workflow. I.e., we filter out codes about replication because when the
    # audit workflow gets in an error state for a given druid, it cannot be
    # further versioned (e.g., remediated). We monitor replication failures via
    # other reporters.
    def handled_merge_codes
      [
        Audit::Results::ACTUAL_VERS_LT_DB_OBJ,
        Audit::Results::DB_UPDATE_FAILED,
        Audit::Results::DB_VERSIONS_DISAGREE,
        Audit::Results::FILE_NOT_IN_MANIFEST,
        Audit::Results::FILE_NOT_IN_MOAB,
        Audit::Results::FILE_NOT_IN_SIGNATURE_CATALOG,
        Audit::Results::INVALID_MANIFEST,
        Audit::Results::MANIFEST_NOT_IN_MOAB,
        Audit::Results::MOAB_FILE_CHECKSUM_MISMATCH,
        Audit::Results::MOAB_NOT_FOUND,
        Audit::Results::SIGNATURE_CATALOG_NOT_IN_MOAB,
        Audit::Results::UNABLE_TO_CHECK_STATUS,
        Audit::Results::UNEXPECTED_VERSION
      ].freeze
    end

    def handle_completed(druid, version, moab_storage_root, _check_name, _result)
      update_status(druid, version, 'moab-valid', moab_storage_root)
      update_status(druid, version, 'preservation-audit', moab_storage_root)
    end

    def handle_single_error(druid, version, moab_storage_root, check_name, result)
      error_message = MessageHelper.invalid_moab_message(check_name, version, moab_storage_root, result)
      update_error_status(druid, version, 'moab-valid', moab_storage_root, error_message)
    end

    def handle_merge_error(druid, version, moab_storage_root, check_name, results)
      error_message = MessageHelper.results_as_message(check_name, version, moab_storage_root, results)
      update_error_status(druid, version, 'preservation-audit', moab_storage_root, error_message)
    end

    def workflow_client
      @workflow_client ||=
        begin
          wf_log = Logger.new('log/workflow_service.log', 'weekly')
          Dor::Workflow::Client.new(
            url: Settings.workflow_services_url,
            logger: wf_log
          )
        end
    end

    def create_workflow(druid, version)
      workflow_client.create_workflow_by_name(druid, 'preservationAuditWF', version: version)
    end

    def update_status(druid, version, process_name, moab_storage_root)
      if Settings.workflow_services_url.present?
        workflow_client.update_status(druid: druid,
                                      workflow: 'preservationAuditWF',
                                      process: process_name,
                                      status: 'completed')
      else
        Rails.logger.warn('no workflow hookup - assume you are in test or dev environment')
      end
    rescue Dor::MissingWorkflowException
      # Create workflow and retry
      create_workflow(druid, version)
      update_status(druid, version, process_name, moab_storage_root)
    end

    def update_error_status(druid, version, process_name, moab_storage_root, error_message)
      if Settings.workflow_services_url.present?
        workflow_client.update_error_status(druid: druid,
                                            workflow: 'preservationAuditWF',
                                            process: process_name,
                                            error_msg: error_message)
      else
        Rails.logger.warn('no workflow hookup - assume you are in test or dev environment')
      end
    rescue Dor::MissingWorkflowException
      # Create workflow and retry
      create_workflow(druid, version)
      update_error_status(druid, version, process_name, moab_storage_root, error_message)
    end
  end
end
