##
# finds Moab objects on a single Moab storage_dir and interacts with Catalog (db)
#   according to method called
class MoabToCatalog

  # NOTE: shameless green! code duplication with seed_catalog
  def self.check_existence(storage_dir, expect_to_create=false)
    results = []
    endpoint = Endpoint.find_by!(storage_location: storage_dir)
    Stanford::MoabStorageDirectory.find_moab_paths(storage_dir) do |druid, path, _path_match_data|
      moab = Moab::StorageObject.new(druid, path)
      po_handler = PreservedObjectHandler.new(druid, moab.current_version_id, moab.size, endpoint)
      if PreservedObject.exists?(druid: druid)
        results << po_handler.confirm_version
      else
        Rails.logger.error "druid: #{druid} expected to exist in catalog but was not found"
        results << po_handler.create if expect_to_create
      end
    end
    results
  end

  # NOTE: shameless green! code duplication with check_existence
  def self.seed_catalog(storage_dir)
    results = []
    endpoint = Endpoint.find_by!(storage_location: storage_dir)
    Stanford::MoabStorageDirectory.find_moab_paths(storage_dir) do |druid, path, _path_match_data|
      moab = Moab::StorageObject.new(druid, path)
      po_handler = PreservedObjectHandler.new(druid, moab.current_version_id, moab.size, endpoint)
      if PreservedObject.exists?(druid: druid)
        Rails.logger.error "druid: #{druid} NOT expected to exist in catalog but was found"
      else
        results << po_handler.create_with_validation
      end
    end
    results
  end

  # Shameless green. In order to run several seed "jobs" in parallel, we would have to refactor.
  def seed_from_disk
    Settings.moab.storage_roots.each do |storage_root|
      start_msg = "#{Time.now.utc.iso8601} Seeding starting for #{storage_root}"
      puts start_msg
      Rails.logger.info start_msg
      self.class.seed_catalog("#{storage_root[1]}/#{Settings.moab.storage_trunk}")
      end_msg = "#{Time.now.utc.iso8601} Seeding ended for #{storage_root}"
      puts end_msg
      Rails.logger.info end_msg
    end
  end

  # Shameless green. Code duplication with seed_from_disk
  def check_existence_from_disk
    Settings.moab.storage_roots.each do |storage_root|
      start_msg = "#{Time.now.utc.iso8601} Check_existence starting for #{storage_root}"
      puts start_msg
      Rails.logger.info start_msg
      self.class.check_existence("#{storage_root[1]}/#{Settings.moab.storage_trunk}")
      end_msg = "#{Time.now.utc.iso8601} Check_existence ended for #{storage_root}"
      puts end_msg
      Rails.logger.info end_msg
    end
  end
end
