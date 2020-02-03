class AddMigratedAtToCompleteMoabs < ActiveRecord::Migration[6.0]
  def change
    add_column :complete_moabs, :migrated_at, :timestamp
    add_column :complete_moabs, :moab_storage_root_id_migrated_from, :bigint
  end
end
