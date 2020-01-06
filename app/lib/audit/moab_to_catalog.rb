# frozen_string_literal: true

module Audit
  #  NOTE:  this class is used by Julian as a CLI tool; it is not called anywhere else
  #
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

    # TODO: If needing to run several seed jobs in parallel, convert seeding to queues.
    def self.seed_catalog_for_all_storage_roots
      MoabStorageRoot.pluck(:storage_location).each { |location| seed_catalog_for_dir(location) }
    end

    def self.populate_moab_storage_root(name)
      ms_root = MoabStorageRoot.find_by!(name: name)
      MoabToCatalog.seed_catalog_for_dir(ms_root.storage_location)
    end
  end
end
