# frozen_string_literal: true

module CompleteMoabService
  # Updates CompletedMoab and associated objects based on a moab on disk after validation of moab.
  class UpdateVersionAfterValidation < UpdateVersion
    def self.execute(druid:, incoming_version:, incoming_size:, moab_storage_root:, checksums_validated: false)
      new(druid: druid, incoming_version: incoming_version, incoming_size: incoming_size,
          moab_storage_root: moab_storage_root).execute(checksums_validated: checksums_validated)
    end

    # checksums_validated may be set to true if the caller takes responsibility for having validated the checksums
    def execute(checksums_validated: false)
      results.check_name = 'update_version_after_validation'
      if invalid?
        results.add_result(AuditResults::INVALID_ARGUMENTS, errors.full_messages)
      elsif CompleteMoab.by_druid(druid).by_storage_root(moab_storage_root).exists?
        Rails.logger.debug "update_version_after_validation #{druid} called"
        if moab_validator.moab_validation_errors.empty?
          # NOTE: we deal with active record transactions in update_online_version, not here
          new_status = (checksums_validated ? 'ok' : 'validity_unknown')
          update_online_version(status: new_status, checksums_validated: checksums_validated)
        else
          Rails.logger.debug "update_version_after_validation #{druid} found validation errors"
          if checksums_validated
            update_online_version(status: 'invalid_moab', checksums_validated: true)
            # for case when no db updates b/c pres_obj version != complete_moab version
            update_cm_invalid_moab unless complete_moab.invalid_moab?
          else
            update_online_version(status: 'validity_unknown')
            # for case when no db updates b/c pres_obj version != complete_moab version
            update_cm_validity_unknown unless complete_moab.validity_unknown?
          end
        end
      else
        results.add_result(AuditResults::DB_OBJ_DOES_NOT_EXIST, 'CompleteMoab')
        if moab_validator.moab_validation_errors.empty?
          create_db_objects('validity_unknown')
        else
          create_db_objects('invalid_moab')
        end
      end

      report_results!
      results
    end

    private

    def update_cm_validity_unknown
      transaction_ok = with_active_record_transaction_and_rescue do
        moab_validator.update_status('validity_unknown')
        complete_moab.update_audit_timestamps(moab_validator.ran_moab_validation?, false)
        complete_moab.save!
      end
      results.remove_db_updated_results unless transaction_ok
    end

    def update_cm_invalid_moab
      transaction_ok = with_active_record_transaction_and_rescue do
        moab_validator.update_status('invalid_moab')
        complete_moab.update_audit_timestamps(moab_validator.ran_moab_validation?, false)
        complete_moab.save!
      end
      results.remove_db_updated_results unless transaction_ok
    end
  end
end
