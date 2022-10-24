# frozen_string_literal: true

module CompleteMoabService
  # Creates CompletedMoab and associated objects based on a moab on disk after validation of moab.
  class CreateAfterValidation < Base
    def self.execute(druid:, incoming_version:, incoming_size:, moab_storage_root:, checksums_validated: false)
      new(druid: druid, incoming_version: incoming_version, incoming_size: incoming_size,
          moab_storage_root: moab_storage_root).execute(checksums_validated: checksums_validated)
    end

    def initialize(druid:, incoming_version:, incoming_size:, moab_storage_root:, check_name: 'create_after_validation')
      super
    end

    # checksums_validated may be set to true if the caller takes responsibility for having validated the checksums
    def execute(checksums_validated: false)
      if invalid?
        results.add_result(AuditResults::INVALID_ARGUMENTS, errors.full_messages)
      elsif CompleteMoab.by_druid(druid).by_storage_root(moab_storage_root).exists?
        results.add_result(AuditResults::DB_OBJ_ALREADY_EXISTS, 'CompleteMoab')
      elsif moab_validator.moab_validation_errors.empty?
        creation_status = (checksums_validated ? 'ok' : 'validity_unknown')
        create_db_objects(creation_status, checksums_validated: checksums_validated)
      else
        create_db_objects('invalid_moab', checksums_validated: checksums_validated)
      end

      report_results!
      results
    end
  end
end
