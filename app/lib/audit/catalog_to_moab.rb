module Audit
  # Catalog to Moab existence check code
  class CatalogToMoab

    def self.logger
      @logger ||= Logger.new(STDOUT)
                        .extend(ActiveSupport::Logger.broadcast(Logger.new(Rails.root.join('log', 'c2m.log'))))
    end

    def self.check_version_on_dir(last_checked_b4_date, storage_dir, limit=Settings.c2m_sql_limit)
      logger.info "#{Time.now.utc.iso8601} C2M check_version starting for #{storage_dir}"

      # pcs_to_audit_relation is an AR Relation; it could return a lot of results, so we want to process in batches.
      # We can't use ActiveRecord's .find_each, because that'll disregard the order .least_recent_version_audit
      # specified.  so we use our own batch processing method, which does respect Relation order.
      pcs_to_audit_relation =
        PreservedCopy.least_recent_version_audit(last_checked_b4_date).by_storage_location(storage_dir)
      ActiveRecordUtils.process_in_batches(pcs_to_audit_relation, limit) do |pc|
        c2m = CatalogToMoab.new(pc, storage_dir)
        c2m.check_catalog_version
      end
    ensure
      logger.info "#{Time.now.utc.iso8601} C2M check_version ended for #{storage_dir}"
    end

    def self.check_version_on_dir_profiled(last_checked_b4_date, storage_dir)
      Profiler.print_profile('C2M_check_version_on_dir') { check_version_on_dir(last_checked_b4_date, storage_dir) }
    end

    def self.check_version_all_dirs(last_checked_b4_date)
      logger.info "#{Time.now.utc.iso8601} C2M check_version_all_dirs starting"
      HostSettings.storage_roots.to_h.each_value do |strg_root_location|
        check_version_on_dir(last_checked_b4_date, "#{strg_root_location}/#{Settings.moab.storage_trunk}")
      end
    ensure
      logger.info "#{Time.now.utc.iso8601} C2M check_version_all_dirs ended"
    end

    def self.check_version_all_dirs_profiled(last_checked_b4_date)
      Profiler.print_profile('C2M_check_version_all_dirs') { check_version_all_dirs(last_checked_b4_date) }
    end

    # ----  INSTANCE code below this line ---------------------------

    include ::MoabValidationHandler

    attr_reader :preserved_copy, :storage_dir, :druid, :results

    def initialize(preserved_copy, storage_dir)
      @preserved_copy = preserved_copy
      @storage_dir = storage_dir
      @druid = preserved_copy.preserved_object.druid
      @results = AuditResults.new(druid, nil, preserved_copy.moab_storage_root)
    end

    # shameless green implementation
    def check_catalog_version
      results.check_name = 'check_catalog_version'
      unless preserved_copy.matches_po_current_version?
        results.add_result(AuditResults::PC_PO_VERSION_MISMATCH,
                           pc_version: preserved_copy.version,
                           po_version: preserved_copy.preserved_object.current_version)
        return results.report_results(Audit::CatalogToMoab.logger)
      end

      unless online_moab_found?
        transaction_ok = ActiveRecordUtils.with_transaction_and_rescue(results) do
          update_status(PreservedCopy::ONLINE_MOAB_NOT_FOUND_STATUS)
          preserved_copy.save!
        end
        results.remove_db_updated_results unless transaction_ok

        results.add_result(AuditResults::MOAB_NOT_FOUND,
                           db_created_at: preserved_copy.created_at.iso8601,
                           db_updated_at: preserved_copy.updated_at.iso8601)
        return results.report_results(Audit::CatalogToMoab.logger)
      end

      return results.report_results(Audit::CatalogToMoab.logger) unless can_validate_current_pres_copy_status?

      compare_version_and_take_action
    end

    alias storage_location storage_dir

    private

    def online_moab_found?
      return true if moab
      false
    end

    # compare the catalog version to the actual Moab;  update the catalog version if the Moab is newer
    #   report results (and return them)
    def compare_version_and_take_action
      moab_version = moab.current_version_id
      results.actual_version = moab_version
      catalog_version = preserved_copy.version
      transaction_ok = ActiveRecordUtils.with_transaction_and_rescue(results) do
        if catalog_version == moab_version
          set_status_as_seen_on_disk(true) unless preserved_copy.status == PreservedCopy::OK_STATUS
          results.add_result(AuditResults::VERSION_MATCHES, 'PreservedCopy')
          results.report_results(Audit::CatalogToMoab.logger)
        elsif catalog_version < moab_version
          set_status_as_seen_on_disk(true)
          pohandler = PreservedObjectHandler.new(druid, moab_version, moab.size, preserved_copy.moab_storage_root)
          pohandler.update_version_after_validation # results reported by this call
        else # catalog_version > moab_version
          set_status_as_seen_on_disk(false)
          results.add_result(
            AuditResults::UNEXPECTED_VERSION, db_obj_name: 'PreservedCopy', db_obj_version: preserved_copy.version
          )
          results.report_results(Audit::CatalogToMoab.logger)
        end

        preserved_copy.update_audit_timestamps(ran_moab_validation?, true)
        preserved_copy.save!
      end
      results.remove_db_updated_results unless transaction_ok
    end
  end
end
