class AddStatusToPreservedCopies < ActiveRecord::Migration[5.1]
  def change
    add_column :preserved_copies, :status, :int, null: false
    add_index :preserved_copies, :status
  end
end
