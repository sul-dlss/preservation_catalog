class AddFromMoabStorageRootToCompleteMoabs < ActiveRecord::Migration[6.0]
  def change
    add_column :complete_moabs, :from_moab_storage_root_id, :bigint
    add_foreign_key :complete_moabs, :moab_storage_roots, column: :from_moab_storage_root_id
  end
end
