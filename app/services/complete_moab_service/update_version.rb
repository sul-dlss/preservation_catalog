# frozen_string_literal: true

module CompleteMoabService
  # Updates CompletedMoab and associated objects based on a moab on disk.
  class UpdateVersion < Base
    def self.execute(druid:, incoming_version:, incoming_size:, moab_storage_root:, checksums_validated: false)
      new(druid: druid, incoming_version: incoming_version, incoming_size: incoming_size,
          moab_storage_root: moab_storage_root).execute(checksums_validated: checksums_validated)
    end

    def initialize(druid:, incoming_version:, incoming_size:, moab_storage_root:, check_name: 'update')
      super
    end

    # checksums_validated may be set to true if the caller takes responsibility for having validated the checksums
    def execute(checksums_validated: false)
      perform_execute do
        Rails.logger.debug "update_version #{druid} called"
        # only change status if checksums_validated is false
        new_status = (checksums_validated ? nil : 'validity_unknown')
        # NOTE: we deal with active record transactions in update_catalog, not here
        update_catalog(status: new_status, set_status_to_unexpected_version: true, checksums_validated: checksums_validated)
      end
    end

    protected

    def update_catalog(status: nil, set_status_to_unexpected_version: false, checksums_validated: false)
      with_active_record_transaction_and_rescue do
        raise_rollback_if_version_mismatch

        if incoming_version > complete_moab.version
          update_complete_moab_to_expected_version(status: status, checksums_validated: checksums_validated)
        else
          status = 'unexpected_version_on_storage' if set_status_to_unexpected_version
          update_complete_moab_to_unexpected_version(status: status)
        end
      end
    end

    def update_complete_moab_to_expected_version(status:, checksums_validated:)
      # add results without db updates
      results.add_result(AuditResults::ACTUAL_VERS_GT_DB_OBJ, db_obj_name: 'CompleteMoab', db_obj_version: complete_moab.version)

      complete_moab.upd_audstamps_version_size(moab_validator.ran_moab_validation?, incoming_version, incoming_size)
      complete_moab.last_checksum_validation = Time.current if checksums_validated && complete_moab.last_checksum_validation
      moab_validator.update_status(status) if status
      complete_moab.save!

      preserved_object.current_version = incoming_version if primary_moab? # we only want to track highest seen version based on primary
      preserved_object.save!
    end

    def update_complete_moab_to_unexpected_version(status:)
      results.add_result(AuditResults::UNEXPECTED_VERSION, db_obj_name: 'CompleteMoab', db_obj_version: complete_moab.version)
      version_comparison_results

      moab_validator.update_status(status) if status
      complete_moab.update_audit_timestamps(moab_validator.ran_moab_validation?, true)
      complete_moab.save!
    end

    # expects @incoming_version to be numeric
    def version_comparison_results
      if incoming_version == complete_moab.version
        results.add_result(AuditResults::VERSION_MATCHES, complete_moab.class.name)
      elsif incoming_version < complete_moab.version
        results.add_result(
          AuditResults::ACTUAL_VERS_LT_DB_OBJ,
          db_obj_name: complete_moab.class.name, db_obj_version: complete_moab.version
        )
      elsif incoming_version > complete_moab.version
        results.add_result(
          AuditResults::ACTUAL_VERS_GT_DB_OBJ,
          db_obj_name: complete_moab.class.name, db_obj_version: complete_moab.version
        )
      end
    end
  end
end
