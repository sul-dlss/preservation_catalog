# frozen_string_literal: true

# Catalog helper methods
# NOTE:  this class is used by Julian as a CLI tool; it is not called anywhere else
#
# finds Moab objects on a single Moab storage_dir and interacts with Catalog (db)
#   according to method called
class CatalogUtils
  def self.logger
    @logger ||= ActiveSupport::BroadcastLogger.new(Logger.new($stdout), Logger.new(Rails.root.join('log', 'audit_moab_to_catalog.log')))
  end

  # this method intended to be called from rake task or via ReST call
  def self.check_existence_for_druid(druid)
    logger.info "#{Time.now.utc.iso8601} M2C check_existence_for_druid starting for #{druid}"
    moab = Stanford::StorageServices.find_storage_object(druid)
    storage_trunk = Settings.moab.storage_trunk
    storage_dir = "#{moab.object_pathname.to_s.split(storage_trunk).first}#{storage_trunk}"
    ms_root = MoabStorageRoot.find_by!(storage_location: storage_dir)
    results = MoabRecordService::CheckExistence.execute(druid: druid, incoming_version: moab.current_version_id, incoming_size: moab.size,
                                                        moab_storage_root: ms_root).to_a
    logger.info "#{results} for #{druid}"
    results
  rescue TypeError
    logger.info "#{Time.now.utc.iso8601} Moab object path does not exist."
  ensure
    logger.info "#{Time.now.utc.iso8601} M2C check_existence_for_druid ended for #{druid}"
  end

  def self.check_existence_for_druid_list(druid_list_file_path)
    CSV.foreach(druid_list_file_path) do |row|
      check_existence_for_druid(row.first)
    end
  end

  def self.populate_catalog_for_dir(storage_dir)
    logger.info "#{Time.now.utc.iso8601} Starting to populate catalog for '#{storage_dir}'"
    results = []
    ms_root = MoabStorageRoot.find_by!(storage_location: storage_dir)
    MoabOnStorage::StorageDirectory.find_moab_paths(storage_dir) do |druid, path, _path_match_data|
      moab = Moab::StorageObject.new(druid, path)
      results << MoabRecordService::CreateAfterValidation.execute(druid: druid, incoming_version: moab.current_version_id,
                                                                  incoming_size: moab.size, moab_storage_root: ms_root).to_a
    end
    results
  ensure
    logger.info "#{Time.now.utc.iso8601} Ended populating catalog for '#{storage_dir}'"
  end

  def self.populate_catalog_for_all_storage_roots
    MoabStorageRoot.pluck(:storage_location).each { |location| populate_catalog_for_dir(location) }
  end

  def self.populate_moab_storage_root(name)
    ms_root = MoabStorageRoot.find_by!(name: name)
    populate_catalog_for_dir(ms_root.storage_location)
  end
end
