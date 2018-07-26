class ChangePreservedCopiesToCompleteMoabs < ActiveRecord::Migration[5.1]
  def change
    rename_table :preserved_copies, :complete_moabs
    rename_column :zipped_moab_versions, :preserved_copy_id, :complete_moab_id
  end
end
