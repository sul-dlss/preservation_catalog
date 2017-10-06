class AddIndexToPreservedObjects < ActiveRecord::Migration[5.1]
  def change
    remove_index :preserved_objects, :druid
    add_index :preserved_objects, :druid, unique: true
  end
end
