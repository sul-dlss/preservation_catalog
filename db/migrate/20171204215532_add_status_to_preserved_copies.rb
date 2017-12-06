class AddStatusToPreservedCopies < ActiveRecord::Migration[5.1]
  def up
    add_column :preserved_copies, :status, :int
    change_column_null :preserved_copies, :status, false
    add_index :preserved_copies, :status
  end

  def down
    remove_column :preserved_copies, :status, :int
  end
end
