class RenameIndexCompleteMoabOnPoAndStorageRoot < ActiveRecord::Migration[6.1]
  def up
    rename_index :complete_moabs, 'index_preserved_copies_on_po_and_storage_root_and_version', 'index_complete_moabs_on_po_and_storage_root_and_version'
  end

  def down
    rename_index :complete_moabs, 'index_complete_moabs_on_po_and_storage_root_and_version', 'index_preserved_copies_on_po_and_storage_root_and_version'
  end
end
