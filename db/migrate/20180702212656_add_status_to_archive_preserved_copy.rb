class AddStatusToArchivePreservedCopy < ActiveRecord::Migration[5.1]
  def change
    remove_column :archive_preserved_copies, :status
    add_column :archive_preserved_copies, :status, :integer, null: false
    add_index :archive_preserved_copies, :status
  end 
end
