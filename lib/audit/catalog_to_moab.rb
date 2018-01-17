require 'druid-tools'
require 'profiler.rb'

# Catalog to Moab existence check code
class CatalogToMoab

  # allows for sharding/parallelization by storage_dir
  # FIXME: remove rubocop exception here when we actually do the SQL call
  # rubocop:disable Lint/UnusedMethodArgument
  def self.check_version_on_dir(last_checked_b4_date, storage_dir)
    # FIXME: ensure last_checked_version_b4_date is in the right format

    # sql = '' # get all PC with last_version_audit date < threshold_date
    #  build a params hash and send it to find_each  in order to chunk it

    # FIXME: chunked SQL query results looped through here
    PreservedCopy.find_each do |pc|
      check_catalog_version(pc, storage_dir)
    end
  end
  # rubocop:enable Lint/UnusedMethodArgument

  def self.check_version_on_dir_profiled(last_checked_b4_date, storage_dir)
    profiler = Profiler.new
    profiler.prof { check_version_on_dir(last_checked_b4_date, storage_dir) }
    profiler.print_results_flat('C2M_check_version_on_dir')
  end

  def self.check_version_all_dirs(last_checked_b4_date)
    # FIXME: ensure last_checked_version_b4_date is in the right format
    Settings.moab.storage_roots.each do |strg_root_name, strg_root_location|
      start_msg = "#{Time.now.utc.iso8601} C2M check_version starting for '#{strg_root_name}' at #{strg_root_location}"
      puts start_msg
      Rails.logger.info start_msg
      check_version_on_dir(last_checked_b4_date, "#{strg_root_location}/#{Settings.moab.storage_trunk}")
      end_msg = "#{Time.now.utc.iso8601} C2M check_version ended for '#{strg_root_name}' at #{strg_root_location}"
      puts end_msg
      Rails.logger.info end_msg
    end
  end

  def self.check_version_all_dirs_profiled(last_checked_b4_date)
    profiler = Profiler.new
    profiler.prof { check_version_all_dirs(last_checked_b4_date) }
    profiler.print_results_flat('C2M_check_version_all_dirs')
  end

  # TODO:  you need to write tests for this!!!
  # FIXME:  temporarily turning off rubocop until we migrate the code to its final home
  # rubocop:disable all
  private_class_method def self.check_catalog_version(preserved_copy, storage_dir)
    # TODO: Pohandler.ensure_po_version_matches_this_pc_version (for non-archived, online moab)

    id = preserved_copy.preserved_object.druid
    catalog_version = preserved_copy.version
    storage_location = preserved_copy.endpoint.storage_location # FIXME: or just, storage_dir?
    results = PreservedObjectHandlerResults.new(id, nil, nil, preserved_copy.endpoint)
    object_dir = "#{storage_location}/#{DruidTools::Druid.new(id).tree.join('/')}"

    moab = Moab::StorageObject.new(id, object_dir)
    # TODO: report error if moab doesn't exist

    moab_version = moab.current_version_id

    # TODO: anything special if preserved_copy.status is not OK_STATUS?

    if catalog_version == moab_version
      p "hooray - #{id} versions match: #{catalog_version}"
      results.add_result(PreservedObjectHandlerResults::VERSION_MATCHES, preserved_copy.class.name)
      # TODO:  original spec asks for verifying files????  read audit requirements
      results.log_results
    elsif catalog_version < moab_version
      results.add_result(PreservedObjectHandlerResults::UNEXPECTED_VERSION, preserved_copy.class.name)
      p "boo - #{id} catalog has #{catalog_version} but moab has #{moab_version}"
      # update the catalog
      pohandler = PreservedObjectHandler.new(id, moab_version, moab.size, preserved_copy.endpoint)
      pohandler.update_version_after_validation # results reported by this call
    else # catalog_version > moab_version
      p "boo - #{id} catalog has #{catalog_version} but moab has #{moab_version}"
      results.add_result(PreservedObjectHandlerResults::UNEXPECTED_VERSION, preserved_copy.class.name)
      if moab_validation_errors.empty?
        update_status(preserved_copy, PreservedCopy::EXPECTED_VERS_NOT_FOUND_ON_STORAGE_STATUS)
      else
        update_status(preserved_copy, PreservedCopy::INVALID_MOAB_STATUS)
      end
      results.log_results
    end

    # TODO: call these methods on PreservedCopy object
    # update_pc_audit_timestamps(preserved_copy, ran_moab_validation, true)
    # update_db_object(preserved_copy)
  end
  # rubocop:enable all

end
