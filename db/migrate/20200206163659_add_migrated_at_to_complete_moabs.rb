class AddMigratedAtToCompleteMoabs < ActiveRecord::Migration[6.0]
  def change
    add_column :complete_moabs, :from_moab_storage_root_id, :bigint
  end
end
