class CreateZipChecksums < ActiveRecord::Migration[5.1]
  def change
    create_table :zip_checksums do |t|
      t.string :md5, null: false
      t.string :create_info, null: false
      t.references :preserved_copy, foreign_key: true, null: false

      t.timestamps
    end
  end
end
