# frozen_string_literal: true

module Audit
  # Service for checking versions, validating moab on storage, and updating catalog.
  class CatalogToMoab
    attr_reader :moab_record, :logger

    def initialize(moab_record)
      @moab_record = moab_record
      @logger = Logger.new(Rails.root.join('log', 'c2m.log'))
    end

    # Check the catalog version (MoabRecord version) against versions of the preserved object and the moab on storage,
    # possibly validate the moab on storage, and possibly update the MoabRecord.
    def check_catalog_version
      return report_results! unless check_preserved_object_and_moab_record_versions_match

      return report_results! unless check_for_moab_on_storage

      # MoabRecord status is not currently 'invalid_checksum'
      return report_results! unless moab_on_storage_validator.can_validate_current_comp_moab_status?(moab_record: moab_record)

      # An expected outcome if nothing changes on storage.
      return report_versions_match if moab_record.version == moab_on_storage_version

      # An expected outcome if new version added to storage. Validate and update the MoabRecord version.
      return validate_moab_on_storage_and_report_results if moab_record.version < moab_on_storage_version

      # An error when moab_record.version > moab_on_storage_version
      report_moab_record_greater_than_moab_on_storage_version
    end

    def results
      @results ||= AuditResults.new(druid: druid, moab_storage_root: moab_record.moab_storage_root,
                                    actual_version: moab_on_storage&.current_version_id, check_name: 'check_catalog_version')
    end

    private

    def druid
      @druid ||= moab_record.preserved_object.druid
    end

    def check_preserved_object_and_moab_record_versions_match
      return true if moab_record.matches_po_current_version?

      results.add_result(AuditResults::DB_VERSIONS_DISAGREE,
                         moab_record_version: moab_record.version,
                         po_version: moab_record.preserved_object.current_version)
      false
    end

    def check_for_moab_on_storage
      return true if moab_on_storage.present?

      persist_db_transaction!(update_audit_timestamps: false) do
        status_handler.update_moab_record_status('moab_on_storage_not_found')
      end

      results.add_result(AuditResults::MOAB_NOT_FOUND,
                         db_created_at: moab_record.created_at.iso8601,
                         db_updated_at: moab_record.updated_at.iso8601)
      false
    end

    def moab_on_storage
      @moab_on_storage ||= MoabOnStorage.moab(druid: druid, storage_location: storage_location)
    end

    def report_results!
      AuditResultsReporter.report_results(audit_results: results, logger: @logger)
    end

    def moab_on_storage_validator
      @moab_on_storage_validator ||= MoabOnStorage::Validator.new(moab: moab_on_storage, audit_results: results)
    end

    def status_handler
      @status_handler ||= StatusHandler.new(audit_results: results, moab_record: moab_record)
    end

    def storage_location
      moab_record.moab_storage_root.storage_location
    end

    def moab_on_storage_version
      moab_on_storage.current_version_id
    end

    def report_versions_match
      persist_db_transaction! do
        unless moab_record.ok? # if status != 'ok'
          status_handler.validate_moab_on_storage_and_set_status(found_expected_version: true,
                                                                 moab_on_storage_validator: moab_on_storage_validator)
        end
        results.add_result(AuditResults::VERSION_MATCHES, 'MoabRecord')
        report_results!
      end
    end

    def validate_moab_on_storage_and_report_results
      persist_db_transaction! do
        status_handler.validate_moab_on_storage_and_set_status(found_expected_version: true, moab_on_storage_validator: moab_on_storage_validator)
        # Update the MoabRecord's version to match the version on storage.
        MoabRecordService::UpdateVersionAfterValidation.execute(druid: druid, incoming_version: moab_on_storage_version,
                                                                incoming_size: moab_on_storage.size,
                                                                moab_storage_root: moab_record.moab_storage_root)
      end
    end

    def report_moab_record_greater_than_moab_on_storage_version
      persist_db_transaction! do
        status_handler.validate_moab_on_storage_and_set_status(found_expected_version: false, moab_on_storage_validator: moab_on_storage_validator)
        results.add_result(
          AuditResults::UNEXPECTED_VERSION, db_obj_name: 'MoabRecord', db_obj_version: moab_record.version
        )
        report_results!
      end
    end

    def persist_db_transaction!(update_audit_timestamps: true)
      transaction_ok = ActiveRecordUtils.with_transaction_and_rescue(results) do
        yield if block_given?

        moab_record.update_audit_timestamps(moab_on_storage_validator.ran_moab_validation?, true) if update_audit_timestamps
        moab_record.save!
      end
      results.remove_db_updated_results unless transaction_ok
    end
  end
end
