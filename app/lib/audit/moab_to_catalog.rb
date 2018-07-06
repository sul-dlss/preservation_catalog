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
      endpoint = Endpoint.find_by!(storage_location: storage_dir)
      po_handler = PreservedObjectHandler.new(druid, moab.current_version_id, moab.size, endpoint)
      results = po_handler.check_existence
      logger.info "#{results} for #{druid}"
      results
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
      endpoint = Endpoint.find_by!(storage_location: storage_dir)
      Stanford::MoabStorageDirectory.find_moab_paths(storage_dir) do |druid, path, _path_match_data|
        moab = Moab::StorageObject.new(druid, path)
        po_handler = PreservedObjectHandler.new(druid, moab.current_version_id, moab.size, endpoint)
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
      endpoint = Endpoint.find_by!(storage_location: storage_dir)
      Stanford::MoabStorageDirectory.find_moab_paths(storage_dir) do |druid, path, _path_match_data|
        moab = Moab::StorageObject.new(druid, path)
        po_handler = PreservedObjectHandler.new(druid, moab.current_version_id, moab.size, endpoint)
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

    def self.drop_endpoint(endpoint_name)
      ApplicationRecord.transaction do
        PreservedCopy.joins(:endpoint).where(
          "endpoints.endpoint_name = :endpoint_name",
          endpoint_name: endpoint_name.to_s
        ).destroy_all
        PreservedObject.left_outer_joins(:preserved_copies).where(preserved_copies: { id: nil }).destroy_all
      end
    end

    def self.populate_endpoint(endpoint_name)
      endpoint = Endpoint.find_by!(endpoint_name: endpoint_name)
      MoabToCatalog.seed_catalog_for_dir(endpoint.storage_location)
    end

    def self.populate_endpoint_profiled(endpoint_name)
      Profiler.print_profile('populate_endpoint') { populate_endpoint(endpoint_name) }
    end
  end
end
