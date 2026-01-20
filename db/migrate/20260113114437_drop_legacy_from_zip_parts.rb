class DropLegacyFromZipParts < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_column :zip_parts, :create_info, :string, null: false
    remove_column :zip_parts, :parts_count, :integer, null: false
    remove_index :zip_parts, :status
    remove_column :zip_parts, :status, :integer, null: false, default: 1
    remove_column :zip_parts, :last_existence_check, :datetime, precision: nil
    remove_column :zip_parts, :last_checksum_validation, :datetime, precision: nil
  end
end
