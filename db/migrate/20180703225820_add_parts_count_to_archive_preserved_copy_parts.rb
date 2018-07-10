class AddPartsCountToArchivePreservedCopyParts < ActiveRecord::Migration[5.1]
  def change
    add_column :archive_preserved_copy_parts, :parts_count, :integer, null: false
    add_column :archive_preserved_copy_parts, :suffix, :string, null: false # e.g. '.z03'
  end
end
