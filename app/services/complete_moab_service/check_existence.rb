# frozen_string_literal: true

module CompleteMoabService
  # Check if CompleteMoab and associated objects exist in the Catalog for a moab on storage.
  # Also, verifies that versions are in alignment.
  class CheckExistence < Base
    def self.execute(druid:, incoming_version:, incoming_size:, moab_storage_root:)
      new(druid: druid, incoming_version: incoming_version, incoming_size: incoming_size, moab_storage_root: moab_storage_root).execute
    end

    def initialize(druid:, incoming_version:, incoming_size:, moab_storage_root:, check_name: 'check_existence')
      super
    end

    def execute
      perform_execute do
        if complete_moab_exists?
          check_versions
        else
          create_missing_complete_moab
        end
      end
    end

    private

    def update_complete_moab_preserved_object_or_set_status
      if validation_errors?
        status_handler.update_complete_moab_status('invalid_moab')
      else
        complete_moab.upd_audstamps_version_size(moab_on_storage_validator.ran_moab_validation?, incoming_version, incoming_size)
        preserved_object.current_version = incoming_version
        preserved_object.save!
      end
    end

    def check_versions
      Rails.logger.debug "check_existence #{druid} called"

      with_active_record_transaction_and_rescue do
        raise_rollback_if_version_mismatch

        return report_results! unless moab_on_storage_validator.can_validate_current_comp_moab_status?(complete_moab: complete_moab)

        if incoming_version == complete_moab.version
          unless complete_moab.status == 'ok'
            status_handler.validate_moab_on_storage_and_set_status(found_expected_version: true,
                                                                   moab_on_storage_validator: moab_on_storage_validator)
          end
          results.add_result(AuditResults::VERSION_MATCHES, 'CompleteMoab')
        elsif incoming_version > complete_moab.version
          unless complete_moab.status == 'ok'
            status_handler.validate_moab_on_storage_and_set_status(found_expected_version: true,
                                                                   moab_on_storage_validator: moab_on_storage_validator)
          end
          results.add_result(AuditResults::ACTUAL_VERS_GT_DB_OBJ, db_obj_name: 'CompleteMoab', db_obj_version: complete_moab.version)
          update_complete_moab_preserved_object_or_set_status
        else # incoming_version < complete_moab.version
          status_handler.validate_moab_on_storage_and_set_status(found_expected_version: false, moab_on_storage_validator: moab_on_storage_validator)
          results.add_result(AuditResults::ACTUAL_VERS_LT_DB_OBJ, db_obj_name: 'CompleteMoab', db_obj_version: complete_moab.version)
        end
        complete_moab.update_audit_timestamps(moab_on_storage_validator.ran_moab_validation?, true)
        complete_moab.save!
      end
    end
  end
end
