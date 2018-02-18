class AddIndexToDbDates < ActiveRecord::Migration[5.1]
  def change
    add_index :preserved_copies, :created_at
    add_index :preserved_copies, :updated_at
    add_index :preserved_objects, :created_at
    add_index :preserved_objects, :updated_at
  end
end
