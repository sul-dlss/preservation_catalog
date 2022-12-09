class RenameCompleteMoabToMoabRecord < ActiveRecord::Migration[7.0]
  def change
    rename_table('complete_moabs', 'moab_records')
    rename_index('moab_records', 'index_complete_moabs_on_po_and_storage_root_and_version', 'index_moab_record_on_po_and_storage_root_and_version')
    rename_index('moab_records', 'index_complete_moab_on_po_and_storage_root_id', 'index_moab_record_on_po_and_storage_root_id')
  end
end
