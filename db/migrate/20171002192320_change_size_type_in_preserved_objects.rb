class ChangeSizeTypeInPreservedObjects < ActiveRecord::Migration[5.1]
  def change
    change_column :preserved_objects, :size, :bigint
  end
end
