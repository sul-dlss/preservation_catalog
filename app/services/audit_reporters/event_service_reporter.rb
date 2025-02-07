# frozen_string_literal: true

module AuditReporters
  # Reports to DOR Event Service.
  class EventServiceReporter < BaseReporter
    private

    def handled_single_codes
      [
        Audit::Results::INVALID_MOAB
      ]
    end

    def handled_merge_codes
      [
        Audit::Results::ACTUAL_VERS_LT_DB_OBJ,
        Audit::Results::DB_OBJ_ALREADY_EXISTS,
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
        Audit::Results::UNEXPECTED_VERSION,
        Audit::Results::ZIP_PART_CHECKSUM_MISMATCH,
        Audit::Results::ZIP_PART_NOT_FOUND,
        Audit::Results::ZIP_PARTS_COUNT_DIFFERS_FROM_ACTUAL,
        Audit::Results::ZIP_PARTS_COUNT_INCONSISTENCY,
        Audit::Results::ZIP_PARTS_NOT_ALL_REPLICATED,
        Audit::Results::ZIP_PARTS_SIZE_INCONSISTENCY
      ].freeze
    end

    def handle_completed(druid, version, storage_area, _check_name, _result)
      create_success_event(druid, version, 'moab-valid', storage_area)
      create_success_event(druid, version, 'preservation-audit', storage_area)
    end

    def handle_single_error(druid, version, storage_area, check_name, result)
      error_message = MessageHelper.invalid_moab_message(check_name, version, storage_area, result)
      create_error_event(druid, version, 'moab-valid', storage_area, error_message)
    end

    def handle_merge_error(druid, version, storage_area, check_name, results)
      error_message = MessageHelper.results_as_message(check_name, version, storage_area, results)
      create_error_event(druid, version, 'preservation-audit', storage_area, error_message)
    end

    def create_success_event(druid, version, process_name, storage_area)
      Dor::Event::Client.create(
        druid: druid,
        type: 'preservation_audit_success',
        data: {
          host: Socket.gethostname,
          invoked_by: 'preservation-catalog',
          storage_area: storage_area&.to_s,
          actual_version: version,
          check_name: process_name
        }
      )
    end

    def create_error_event(druid, version, process_name, storage_area, error_message)
      Dor::Event::Client.create(
        druid: druid,
        type: 'preservation_audit_failure',
        data: {
          host: Socket.gethostname,
          invoked_by: 'preservation-catalog',
          storage_area: storage_area&.to_s,
          actual_version: version,
          check_name: process_name,
          error: error_message
        }
      )
    end
  end
end
