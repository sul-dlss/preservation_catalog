class AddFromMoabStorageRootToCompleteMoabs < ActiveRecord::Migration[6.0]
  def change
    add_column :complete_moabs, :from_moab_storage_root_id, :bigint
    add_foreign_key :complete_moabs, :moab_storage_roots, column: :from_moab_storage_root_id 
    add_index :complete_moabs, :from_moab_storage_root_id, :unique => false,
      name: 'index_complete_moabs_on_from_moab_storage_root_id' 
  end
end
