class RemoveStatusFromZippedMoabVersions < ActiveRecord::Migration[5.1]
  def change
    remove_column :zipped_moab_versions, :status, :integer
  end
end
