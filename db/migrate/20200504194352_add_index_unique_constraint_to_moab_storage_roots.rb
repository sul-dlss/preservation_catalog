class AddIndexUniqueConstraintToMoabStorageRoots < ActiveRecord::Migration[6.0]
  def change
    remove_index :moab_storage_roots, :name=> "index_moab_storage_roots_on_storage_location"
    add_index :moab_storage_roots, [:storage_location], :unique => true
  end
end
