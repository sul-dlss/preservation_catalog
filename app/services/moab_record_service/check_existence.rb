# frozen_string_literal: true

module MoabRecordService
  # Check if MoabRecord and associated objects exist in the Catalog for a moab on storage.
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
        if moab_record_exists?
          check_versions
        else
          create_missing_moab_record
        end
        ReplicationJob.perform_later(preserved_object) if perform_replication?
      end
    end

    private

    def update_moab_record_preserved_object_or_set_status
      if validation_errors?
        status_handler.update_moab_record_status('invalid_moab')
      else
        moab_record.upd_audstamps_version_size(moab_on_storage_validator.ran_moab_validation?, incoming_version, incoming_size)
        preserved_object.current_version = incoming_version
        preserved_object.save!

        @perform_replication = true
      end
    end

    def check_versions
      Rails.logger.debug "check_existence #{druid} called"

      with_active_record_transaction_and_rescue do
        raise_rollback_if_version_mismatch

        return report_results! unless moab_on_storage_validator.can_validate_current_comp_moab_status?(moab_record: moab_record)

        if incoming_version == moab_record.version
          unless moab_record.status == 'ok'
            status_handler.validate_moab_on_storage_and_set_status(found_expected_version: true,
                                                                   moab_on_storage_validator: moab_on_storage_validator)
          end
          results.add_result(Audit::Results::VERSION_MATCHES, 'MoabRecord')
        elsif incoming_version > moab_record.version
          unless moab_record.status == 'ok'
            status_handler.validate_moab_on_storage_and_set_status(found_expected_version: true,
                                                                   moab_on_storage_validator: moab_on_storage_validator)
          end
          results.add_result(Audit::Results::ACTUAL_VERS_GT_DB_OBJ, db_obj_name: 'MoabRecord', db_obj_version: moab_record.version)
          update_moab_record_preserved_object_or_set_status
        else # incoming_version < moab_record.version
          status_handler.validate_moab_on_storage_and_set_status(found_expected_version: false, moab_on_storage_validator: moab_on_storage_validator)
          results.add_result(Audit::Results::ACTUAL_VERS_LT_DB_OBJ, db_obj_name: 'MoabRecord', db_obj_version: moab_record.version)
        end
        moab_record.update_audit_timestamps(moab_on_storage_validator.ran_moab_validation?, true)
        moab_record.save!
      end
    end

    def perform_replication?
      @perform_replication ||= false
    end
  end
end
