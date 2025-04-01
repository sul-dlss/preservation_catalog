# frozen_string_literal: true

module Audit
  # Service for validating Moab checksums on storage, updating the MoabRecord db record, and reporting results.
  class ChecksumValidationOrchestrator
    attr_reader :moab_record

    delegate :moab_storage_root, :preserved_object, to: :moab_record
    delegate :storage_location, to: :moab_storage_root
    delegate :druid, to: :preserved_object
    delegate :moab_on_storage_absent?, :latest_moab_storage_object_version, :object_dir, :moab_on_storage_validator,
             :validate_manifest_inventories, :validate_signature_catalog, to: :checksum_validator

    def initialize(moab_record, logger: nil)
      @moab_record = moab_record
      @logger = logger
    end

    def validate_checksums
      # check first thing to make sure the moab is present on storage, otherwise weird errors later
      return persist_db_transaction! { status_handler.mark_moab_not_found } if moab_on_storage_absent?

      # These will populate the results object
      validate_manifest_inventories
      validate_signature_catalog

      persist_db_transaction!(clear_connections: true) do
        moab_record.last_checksum_validation = Time.current
        if results.results.empty?
          results.add_result(Audit::Results::MOAB_CHECKSUM_VALID)
          moab_record.update_audit_timestamps(true, true)

          validate_versions
        else
          status_handler.update_moab_record_status('invalid_checksum')
        end
      end
    end

    def checksum_validator
      @checksum_validator ||= ChecksumValidator.new(moab_storage_object: moab_on_storage, logger:, results:)
    end

    def versions_match?
      moab_on_storage.current_version_id == moab_record.version
    end

    def validate_versions
      # validate_moab_on_storage_and_set_status will update results and moab_record
      status_handler.validate_moab_on_storage_and_set_status(found_expected_version: versions_match?, moab_on_storage_validator:,
                                                             caller_validates_checksums: true)

      return if versions_match?
      results.add_result(Audit::Results::UNEXPECTED_VERSION,
                         actual_version: moab_on_storage.current_version_id,
                         db_obj_name: 'MoabRecord',
                         db_obj_version: moab_record.version)
    end

    def status_handler
      @status_handler ||= StatusHandler.new(audit_results: results, moab_record: moab_record)
    end

    def moab_on_storage
      @moab_on_storage ||= MoabOnStorage.moab(storage_location:, druid:)
    end

    def results
      @results ||= Audit::Results.new(druid:, moab_storage_root:, actual_version: moab_on_storage.current_version_id,
                                      check_name: 'validate_checksums')
    end

    def persist_db_transaction!(clear_connections: false)
      # This is to deal with db connection timeouts.
      ActiveRecord::ConnectionAdapters::ConnectionHandler.new.clear_active_connections! if clear_connections

      transaction_ok = ActiveRecordUtils.with_transaction_and_rescue(results) do
        yield if block_given?
        moab_record.save!
      end
      results.remove_db_updated_results unless transaction_ok
      AuditResultsReporter.report_results(audit_results: results, logger: logger)
    end

    def logger
      @logger ||= ActiveSupport::BroadcastLogger.new(Logger.new($stdout), Logger.new(Rails.root.join('log', 'audit_checksum_validation.log')))
    end
  end
end
