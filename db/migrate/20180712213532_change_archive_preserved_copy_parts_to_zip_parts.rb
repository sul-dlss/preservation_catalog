class ChangeArchivePreservedCopyPartsToZipParts < ActiveRecord::Migration[5.1]
  def change
    rename_table :archive_preserved_copy_parts, :zip_parts
  end
end
