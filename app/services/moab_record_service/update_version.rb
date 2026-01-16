# frozen_string_literal: true

module MoabRecordService
  # Updates MoabRecord and associated objects based on a moab on storage.
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
        # After the transaction is complete:
        ReplicationJob.perform_later(preserved_object) if perform_replication?
      end
    end

    private

    def update_catalog(status: nil, set_status_to_unexpected_version: false, checksums_validated: false)
      with_active_record_transaction_and_rescue do
        raise_rollback_if_version_mismatch

        if incoming_version > moab_record.version
          update_moab_record_to_expected_version(status: status, checksums_validated: checksums_validated)
        else
          status = 'unexpected_version_on_storage' if set_status_to_unexpected_version
          update_moab_record_to_unexpected_version(status: status)
        end
      end
    end

    def update_moab_record_to_expected_version(status:, checksums_validated:)
      # add results without db updates
      results.add_result(Audit::Results::ACTUAL_VERS_GT_DB_OBJ, db_obj_name: 'MoabRecord', db_obj_version: moab_record.version)

      moab_record.upd_audstamps_version_size(moab_on_storage_validator.ran_moab_validation?, incoming_version, incoming_size)
      moab_record.last_checksum_validation = Time.current if checksums_validated && moab_record.last_checksum_validation
      status_handler.update_moab_record_status(status) if status
      moab_record.save!

      preserved_object.current_version = incoming_version
      preserved_object.save!

      @perform_replication = true
    end

    def update_moab_record_to_unexpected_version(status:)
      results.add_result(Audit::Results::UNEXPECTED_VERSION, db_obj_name: 'MoabRecord', db_obj_version: moab_record.version)
      version_comparison_results

      status_handler.update_moab_record_status(status) if status
      moab_record.update_audit_timestamps(moab_on_storage_validator.ran_moab_validation?, true)
      moab_record.save!
    end

    # expects @incoming_version to be numeric
    def version_comparison_results
      if incoming_version == moab_record.version
        results.add_result(Audit::Results::VERSION_MATCHES, moab_record.class.name)
      elsif incoming_version < moab_record.version
        results.add_result(
          Audit::Results::ACTUAL_VERS_LT_DB_OBJ,
          db_obj_name: moab_record.class.name, db_obj_version: moab_record.version
        )
      elsif incoming_version > moab_record.version
        results.add_result(
          Audit::Results::ACTUAL_VERS_GT_DB_OBJ,
          db_obj_name: moab_record.class.name, db_obj_version: moab_record.version
        )
      end
    end

    def perform_replication?
      @perform_replication ||= false
    end
  end
end
