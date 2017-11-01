class RemoveSizeFromPreservedObjects < ActiveRecord::Migration[5.1]
  def change
    remove_column :preserved_objects, :size, :bigint
  end
end
