class AddUniqueZippedMoabVersions < ActiveRecord::Migration[6.1]
  def change
    add_index :zipped_moab_versions, [:preserved_object_id, :zip_endpoint_id, :version], unique: true, name: 'index_unique_on_zipped_moab_versions'
  end
end
