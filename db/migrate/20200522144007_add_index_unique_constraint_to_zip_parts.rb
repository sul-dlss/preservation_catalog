class AddIndexUniqueConstraintToZipParts < ActiveRecord::Migration[6.0]
  def change
    add_index :zip_parts, [:zipped_moab_version_id, :suffix], :unique => true
  end
end
