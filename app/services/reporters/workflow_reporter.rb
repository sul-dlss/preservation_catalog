# frozen_string_literal: true

module Reporters
  # Reports to DOR Workflow Service.
  class WorkflowReporter < BaseReporter
    protected

    def handled_single_codes
      [
        AuditResults::INVALID_MOAB
      ]
    end

    def handled_merge_codes
      [
        AuditResults::ACTUAL_VERS_LT_DB_OBJ,
        AuditResults::CM_PO_VERSION_MISMATCH,
        AuditResults::DB_OBJ_ALREADY_EXISTS,
        AuditResults::DB_UPDATE_FAILED,
        AuditResults::FILE_NOT_IN_MANIFEST,
        AuditResults::FILE_NOT_IN_MOAB,
        AuditResults::FILE_NOT_IN_SIGNATURE_CATALOG,
        AuditResults::INVALID_MANIFEST,
        AuditResults::MANIFEST_NOT_IN_MOAB,
        AuditResults::MOAB_FILE_CHECKSUM_MISMATCH,
        AuditResults::MOAB_NOT_FOUND,
        AuditResults::SIGNATURE_CATALOG_NOT_IN_MOAB,
        AuditResults::UNABLE_TO_CHECK_STATUS,
        AuditResults::UNEXPECTED_VERSION
        # Temporary fix for workflow-service throwing exceptions
        # because some error reports from MoabReplicationAudit are too long
        # ZIP_PART_CHECKSUM_MISMATCH,
        # ZIP_PART_NOT_FOUND,
        # ZIP_PARTS_COUNT_DIFFERS_FROM_ACTUAL,
        # ZIP_PARTS_COUNT_INCONSISTENCY,
        # ZIP_PARTS_NOT_ALL_REPLICATED
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

    private

    def workflow_client
      @workflow_client ||= begin
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
        workflow_client.update_status(druid: druid, workflow: 'preservationAuditWF',
                                      process: process_name, status: 'completed')
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
        workflow_client.update_error_status(druid: druid, workflow: 'preservationAuditWF',
                                            process: process_name, error_msg: error_message)
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
