class ChangeArchivePreservedCopiesToZippedMoabVersions < ActiveRecord::Migration[5.1]
  def change
    rename_table :archive_preserved_copies, :zipped_moab_versions
  end
end
