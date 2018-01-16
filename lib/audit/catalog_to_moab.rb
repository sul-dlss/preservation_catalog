require 'druid-tools'
require 'profiler.rb'

# Catalog to Moab existence check code
class CatalogToMoab

  # FIXME:  temporarily turning off rubocop until we migrate the code to its final home
  # rubocop:disable all
  def self.check_version_on_dir(last_checked_b4_date, storage_dir)
    # TODO: ensure last_checked_version_b4_date is in the right format

    # FIXME:  move the guts of this to someplace else (possibly leaving SQL query here, but object manipulation elsewhere)
    #sql = '' # get all PC with last_version_audit date < threshold_date
    #  build a params hash and send it to find_each  in order to chunk it

    #  we'll NEVER do the whole db this way;  it was a way to start --
    #   replace with appropriate chunked sql query ...
    PreservedCopy.find_each do |pc|
      # TODO: probably move of this to a method in PreservedCopy object, or pohandler or?
      id = pc.preserved_object.druid
      catalog_version = pc.current_version
      storage_location = pc.endpoint.storage_location
      druid = DruidTools::Druid.new(id)
      object_dir = "#{storage_location}/#{druid.tree.join('/')}"

      moab = Moab::StorageObject.new(id, object_dir)
      moab_version = moab.current_version_id
      if catalog_version == moab_version
        p "hurray - #{id} versions match: #{catalog_version}"
      else
        p "boo - #{id} catalog has #{catalog_version} but moab has #{moab_version}"
      end

      # TODO: update status, timestamps, report errors, log, etc. -- methods in PreservedCopy model? pohandler?
    end
  end
  # rubocop:enable all

  def self.check_version_on_dir_profiled(last_checked_b4_date, storage_dir)
    profiler = Profiler.new
    profiler.prof { check_version_on_dir(last_checked_b4_date, storage_dir) }
    profiler.print_results_flat('C2M_check_version_on_dir')
  end

  def self.check_version_all_dirs(last_checked_b4_date)
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
end
