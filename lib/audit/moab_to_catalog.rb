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
        results << po_handler.create
      end
    end
    results
  end

  # Shameless green. In order to run several seed "jobs" in parallel, we would have to refactor.
  def seed_from_disk
    Settings.moab.storage_roots.each do |storage_root|
      self.class.seed_catalog("#{storage_root[1]}/#{Settings.moab.storage_trunk}")
    end
  end
end
