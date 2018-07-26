module Audit
  # finds Moab objects on a single Moab storage_dir and interacts with Catalog (db)
  #   according to method called
  class MoabToCatalog

    def self.logger
      @logger ||= Logger.new(STDOUT)
                        .extend(ActiveSupport::Logger.broadcast(Logger.new(Rails.root.join('log', 'm2c.log'))))
    end

    # this method intended to be called from rake task or via ReST call
    def self.check_existence_for_druid(druid)
      logger.info "#{Time.now.utc.iso8601} M2C check_existence_for_druid starting for #{druid}"
      moab = Stanford::StorageServices.find_storage_object(druid)
      storage_trunk = Settings.moab.storage_trunk
      storage_dir = "#{moab.object_pathname.to_s.split(storage_trunk).first}#{storage_trunk}"
      ms_root = MoabStorageRoot.find_by!(storage_location: storage_dir)
      po_handler = PreservedObjectHandler.new(druid, moab.current_version_id, moab.size, ms_root)
      po_handler.logger = Audit::MoabToCatalog.logger
      results = po_handler.check_existence
      logger.info "#{results} for #{druid}"
      results
    rescue TypeError
      logger.info "#{Time.now.utc.iso8601} Moab object path does not exist."
    ensure
      logger.info "#{Time.now.utc.iso8601} M2C check_existence_for_druid ended for #{druid}"
    end

    def self.check_existence_for_druid_list(druid_list_file_path)
      CSV.foreach(druid_list_file_path) do |row|
        MoabToCatalog.check_existence_for_druid(row.first)
      end
    end

    # NOTE: shameless green! code duplication with seed_catalog_for_dir but pohandler.check_existence
    def self.check_existence_for_dir(storage_dir)
      logger.info "#{Time.now.utc.iso8601} M2C check_existence starting for '#{storage_dir}'"
      results = []
      ms_root = MoabStorageRoot.find_by!(storage_location: storage_dir)
      Stanford::MoabStorageDirectory.find_moab_paths(storage_dir) do |druid, path, _path_match_data|
        moab = Moab::StorageObject.new(druid, path)
        po_handler = PreservedObjectHandler.new(druid, moab.current_version_id, moab.size, ms_root)
        results.concat po_handler.check_existence
      end
      results
    ensure
      logger.info "#{Time.now.utc.iso8601} M2C check_existence ended for '#{storage_dir}'"
    end

    def self.check_existence_for_dir_profiled(storage_dir)
      Profiler.print_profile('M2C_check_existence_for_dir') { check_existence_for_dir(storage_dir) }
    end

    # NOTE: shameless green! code duplication with check_existence_for_dir but poh.create_after_validation
    def self.seed_catalog_for_dir(storage_dir)
      logger.info "#{Time.now.utc.iso8601} Seeding starting for '#{storage_dir}'"
      results = []
      ms_root = MoabStorageRoot.find_by!(storage_location: storage_dir)
      Stanford::MoabStorageDirectory.find_moab_paths(storage_dir) do |druid, path, _path_match_data|
        moab = Moab::StorageObject.new(druid, path)
        po_handler = PreservedObjectHandler.new(druid, moab.current_version_id, moab.size, ms_root)
        results << po_handler.create_after_validation
      end
      results
    ensure
      logger.info "#{Time.now.utc.iso8601} Seeding ended for '#{storage_dir}'"
    end

    # Shameless green. In order to run several seed "jobs" in parallel, we would have to refactor.
    def self.seed_catalog_for_all_storage_roots
      logger.info "#{Time.now.utc.iso8601} Seeding for all storage roots starting"
      HostSettings.storage_roots.to_h.each_value do |strg_root_location|
        seed_catalog_for_dir("#{strg_root_location}/#{Settings.moab.storage_trunk}")
      end
    ensure
      logger.info "#{Time.now.utc.iso8601} Seeding for all storage roots ended'"
    end

    def self.seed_catalog_for_all_storage_roots_profiled
      Profiler.print_profile('seed_catalog_for_all_storage_roots') { seed_catalog_for_all_storage_roots }
    end

    # Shameless green. Code duplication with seed_catalog_for_all_storage_roots
    def self.check_existence_for_all_storage_roots
      logger.info "#{Time.now.utc.iso8601} M2C check_existence for all storage roots starting'"
      HostSettings.storage_roots.to_h.each_value do |strg_root_location|
        check_existence_for_dir("#{strg_root_location}/#{Settings.moab.storage_trunk}")
      end
    ensure
      logger.info "#{Time.now.utc.iso8601} M2C check_existence for all storage roots ended'"
    end

    def self.check_existence_for_all_storage_roots_profiled
      Profiler.print_profile('M2C_check_existence_for_all_storage_roots') { check_existence_for_all_storage_roots }
    end

    # @todo This method may not be useful anymore.  Every PC has 1..n ZMVs, so either this method must
    # figure out how to specially delete them too, or we can loosen the restrictions from PC to ZMV
    # @todo Move this method (and pouplate_m_s_r/seed_catalog_for_dir) onto the MoabStorageRoot model
    def self.drop_moab_storage_root(name)
      ms_root = MoabStorageRoot.find_by!(name: name.to_s)
      ApplicationRecord.transaction do
        ms_root.complete_moabs.destroy_all
        PreservedObject.without_complete_moabs.destroy_all
      end
    end

    def self.populate_moab_storage_root(name)
      ms_root = MoabStorageRoot.find_by!(name: name)
      MoabToCatalog.seed_catalog_for_dir(ms_root.storage_location)
    end

    def self.populate_moab_storage_root_profiled(name)
      Profiler.print_profile('populate_moab_storage_root') { populate_moab_storage_root(name) }
    end
  end
end
