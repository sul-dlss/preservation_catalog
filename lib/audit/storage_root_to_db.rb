##
# Method that will check the online service disks for the existence of moabs in postgres database
class StorageRootToDB
  def self.check_online_to_db_existence(storage_dir)
    results = []
    MoabStorageDirectory.find_moab_paths(storage_dir) do |druid, _path, _path_match_data|
      storage_root_current_version = Stanford::StorageServices.current_version(druid)
      storage_root_size = Stanford::StorageServices.object_size(druid)
      po_handler = PreservedObjectHandler.new(druid, storage_root_current_version, storage_root_size)
      results << po_handler.update_or_create
    end
    results
  end
end
