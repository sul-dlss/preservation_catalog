class AddZipFieldsToArchivePreservedCopyPart < ActiveRecord::Migration[5.1]
  def change
    add_column :archive_preserved_copy_parts, :md5, :string, null: false
    add_column :archive_preserved_copy_parts, :create_info, :string, null: false
  end
end
