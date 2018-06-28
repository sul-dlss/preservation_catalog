class CreateArchivePreservedCopies < ActiveRecord::Migration[5.1]
  def change
    create_table :archive_preserved_copies do |t|
      t.integer :version, null: false
      t.string :status, null: false, index: true
      t.datetime :last_existence_check, index: true
      t.references :preserved_copy, index: true, foreign_key: true, null: false
      t.references :archive_endpoint, index: true, foreign_key: true, null: false

      t.timestamps
    end
  end
end
