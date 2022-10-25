# frozen_string_literal: true

module CompleteMoabService
  # Check if CompleteMoab and associated objects exist in the Catalog for a moab on disk.
  # Also, verifies that versions are in alignment.
  class CheckExistence < Base
    def self.execute(druid:, incoming_version:, incoming_size:, moab_storage_root:)
      new(druid: druid, incoming_version: incoming_version, incoming_size: incoming_size, moab_storage_root: moab_storage_root).execute
    end

    def initialize(druid:, incoming_version:, incoming_size:, moab_storage_root:, check_name: 'check_existence')
      super
    end

    # rubocop:disable Metrics/BlockLength
    def execute
      perform_execute do
        if CompleteMoab.by_druid(druid).by_storage_root(moab_storage_root).exists?
          Rails.logger.debug "check_existence #{druid} called"

          with_active_record_transaction_and_rescue do
            raise_rollback_if_version_mismatch

            return report_results! unless moab_validator.can_validate_current_comp_moab_status?

            if incoming_version == complete_moab.version
              moab_validator.set_status_as_seen_on_disk(true) unless complete_moab.status == 'ok'
              results.add_result(AuditResults::VERSION_MATCHES, 'CompleteMoab')
            elsif incoming_version > complete_moab.version
              moab_validator.set_status_as_seen_on_disk(true) unless complete_moab.status == 'ok'
              results.add_result(AuditResults::ACTUAL_VERS_GT_DB_OBJ, db_obj_name: 'CompleteMoab', db_obj_version: complete_moab.version)
              update_complete_moab_preserved_object_or_set_status
            else # incoming_version < complete_moab.version
              moab_validator.set_status_as_seen_on_disk(false)
              results.add_result(AuditResults::ACTUAL_VERS_LT_DB_OBJ, db_obj_name: 'CompleteMoab', db_obj_version: complete_moab.version)
            end
            complete_moab.update_audit_timestamps(moab_validator.ran_moab_validation?, true)
            complete_moab.save!
          end
        else
          results.add_result(AuditResults::DB_OBJ_DOES_NOT_EXIST, 'CompleteMoab')
          if moab_validator.moab_validation_errors.empty?
            create_db_objects('validity_unknown')
          else
            create_db_objects('invalid_moab')
          end
        end
      end
    end
    # rubocop:enable Metrics/BlockLength

    private

    def update_complete_moab_preserved_object_or_set_status
      if moab_validator.moab_validation_errors.empty?
        complete_moab.upd_audstamps_version_size(moab_validator.ran_moab_validation?, incoming_version, incoming_size)
        preserved_object.current_version = incoming_version if primary_moab? # we only want to track highest seen version based on primary
        preserved_object.save!
      else
        moab_validator.update_status('invalid_moab')
      end
    end
  end
end
