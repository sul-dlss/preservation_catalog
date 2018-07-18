class ChangeArchivePreservedCopiesToZippedMoabVersions < ActiveRecord::Migration[5.1]
  def change
    rename_table :archive_preserved_copies, :zipped_moab_versions
    rename_column :zip_parts, :archive_preserved_copy_id, :zipped_moab_version_id
  end
end
