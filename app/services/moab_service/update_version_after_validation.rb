# frozen_string_literal: true

module MoabService
  # Updates MoabRecord and associated objects based on a moab on storage after validation of moab.
  class UpdateVersionAfterValidation < UpdateVersion
    def self.execute(druid:, incoming_version:, incoming_size:, moab_storage_root:, checksums_validated: false)
      new(druid: druid, incoming_version: incoming_version, incoming_size: incoming_size,
          moab_storage_root: moab_storage_root).execute(checksums_validated: checksums_validated)
    end

    def initialize(druid:, incoming_version:, incoming_size:, moab_storage_root:, check_name: 'update_after_validation')
      super
    end

    # checksums_validated may be set to true if the caller takes responsibility for having validated the checksums
    def execute(checksums_validated: false)
      perform_execute do
        if moab_record_exists?
          Rails.logger.debug "update_version_after_validation #{druid} called"
          if validation_errors?
            Rails.logger.debug "update_version_after_validation #{druid} found validation errors"
            if checksums_validated
              record_invalid
            else
              record_validity_unknown
            end
          else
            record_no_validation_errors(checksums_validated)
          end
        else
          create_missing_moab_record
        end
      end
    end

    private

    def record_no_validation_errors(checksums_validated)
      new_status = (checksums_validated ? 'ok' : 'validity_unknown')
      update_catalog(status: new_status, checksums_validated: checksums_validated)
    end

    def record_validity_unknown
      update_catalog(status: 'validity_unknown')
      # for case when no db updates b/c pres_obj version != moab_record version
      update_moab_record_to_validity_unknown unless moab_record.validity_unknown?
    end

    def record_invalid
      update_catalog(status: 'invalid_moab', checksums_validated: true)
      # for case when no db updates b/c pres_obj version != moab_record version
      update_moab_record_to_invalid_moab unless moab_record.invalid_moab?
    end

    def update_moab_record_to_validity_unknown
      with_active_record_transaction_and_rescue do
        status_handler.update_moab_record_status('validity_unknown')
        moab_record.update_audit_timestamps(moab_on_storage_validator.ran_moab_validation?, false)
        moab_record.save!
      end
    end

    def update_moab_record_to_invalid_moab
      with_active_record_transaction_and_rescue do
        status_handler.update_moab_record_status('invalid_moab')
        moab_record.update_audit_timestamps(moab_on_storage_validator.ran_moab_validation?, false)
        moab_record.save!
      end
    end
  end
end
