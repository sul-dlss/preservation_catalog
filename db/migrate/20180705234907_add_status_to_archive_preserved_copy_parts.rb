class AddStatusToArchivePreservedCopyParts < ActiveRecord::Migration[5.1]
  def change
    add_column :archive_preserved_copy_parts, :status, :int, null: false, default: 1
  end
end
