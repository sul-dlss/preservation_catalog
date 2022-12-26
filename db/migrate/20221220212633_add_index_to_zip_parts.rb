class AddIndexToZipParts < ActiveRecord::Migration[7.0]
  def change
    add_index :zip_parts, :status
  end
end
