##
# Method that will check the a single moab service disk for the existence of moabs in postgres database
class MoabToCatalog
  def self.check_moab_to_catalog_existence(storage_dir)
    results = []
    MoabStorageDirectory.find_moab_paths(storage_dir) do |druid, path, _path_match_data|
      moab = Moab::StorageObject.new(druid, path)
      moab_current_version = moab.current_version_id
      moab_size = Stanford::StorageServices.object_size(druid)
      po_handler = PreservedObjectHandler.new(druid, moab_current_version, moab_size)
      results << po_handler.update_or_create
    end
    results
  end
end
