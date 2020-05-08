class AddIndexUniqueConstraintDruidMoabStorageRootToCompleteMoab < ActiveRecord::Migration[6.0]
  def change
    add_index :complete_moabs, [:preserved_object_id, :moab_storage_root_id], :unique => true, :name => 'index_complete_moab_on_po_and_storage_root_id'
  end
end
