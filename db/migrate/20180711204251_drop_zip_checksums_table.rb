class DropZipChecksumsTable < ActiveRecord::Migration[5.1]
  def change
    drop_table :zip_checksums
  end
end
