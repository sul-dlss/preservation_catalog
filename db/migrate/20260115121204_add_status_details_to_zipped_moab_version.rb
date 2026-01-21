class AddStatusDetailsToZippedMoabVersion < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :zipped_moab_versions, :status_details, :string
  end
end
