# frozen_string_literal: true

module Audit
  # Catalog to Moab existence check code
  class CatalogToMoab
    attr_reader :complete_moab, :druid, :results, :logger

    delegate :can_validate_current_comp_moab_status?,
             :moab,
             :ran_moab_validation?,
             :set_status_as_seen_on_disk,
             :update_status,
             to: :moab_validator

    def initialize(complete_moab)
      @complete_moab = complete_moab
      @druid = complete_moab.preserved_object.druid
      @logger = Logger.new(Rails.root.join('log', 'c2m.log'))
      @results = AuditResults.new(druid: druid, moab_storage_root: complete_moab.moab_storage_root, check_name: 'check_catalog_version')
    end

    # shameless green implementation
    def check_catalog_version
      unless complete_moab.matches_po_current_version?
        results.add_result(AuditResults::CM_PO_VERSION_MISMATCH,
                           cm_version: complete_moab.version,
                           po_version: complete_moab.preserved_object.current_version)
        return report_results!
      end

      unless online_moab_found?
        transaction_ok = ActiveRecordUtils.with_transaction_and_rescue(results) do
          update_status('online_moab_not_found')
          complete_moab.save!
        end
        results.remove_db_updated_results unless transaction_ok

        results.add_result(AuditResults::MOAB_NOT_FOUND,
                           db_created_at: complete_moab.created_at.iso8601,
                           db_updated_at: complete_moab.updated_at.iso8601)
        return report_results!
      end

      return report_results! unless can_validate_current_comp_moab_status?

      compare_version_and_take_action
    end

    private

    def report_results!
      AuditResultsReporter.report_results(audit_results: results, logger: @logger)
    end

    def moab_validator
      @moab_validator ||= MoabValidator.new(druid: druid, storage_location: storage_location, results: results, complete_moab: complete_moab)
    end

    def storage_location
      complete_moab.moab_storage_root.storage_location
    end

    def online_moab_found?
      return true if moab
      false
    end

    # compare the catalog version to the actual Moab;  update the catalog version if the Moab is newer
    #   report results (and return them)
    def compare_version_and_take_action
      moab_version = moab.current_version_id
      results.actual_version = moab_version
      catalog_version = complete_moab.version
      transaction_ok = ActiveRecordUtils.with_transaction_and_rescue(results) do
        if catalog_version == moab_version
          set_status_as_seen_on_disk(true) unless complete_moab.ok?
          results.add_result(AuditResults::VERSION_MATCHES, 'CompleteMoab')
          report_results!
        elsif catalog_version < moab_version
          set_status_as_seen_on_disk(true)
          CompleteMoabService::UpdateVersionAfterValidation.execute(druid: druid, incoming_version: moab_version, incoming_size: moab.size,
                                                                    moab_storage_root: complete_moab.moab_storage_root)
        else # catalog_version > moab_version
          set_status_as_seen_on_disk(false)
          results.add_result(
            AuditResults::UNEXPECTED_VERSION, db_obj_name: 'CompleteMoab', db_obj_version: complete_moab.version
          )
          report_results!
        end

        complete_moab.update_audit_timestamps(ran_moab_validation?, true)
        complete_moab.save!
      end
      results.remove_db_updated_results unless transaction_ok
    end
  end
end
