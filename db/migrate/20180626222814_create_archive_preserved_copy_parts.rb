class CreateArchivePreservedCopyParts < ActiveRecord::Migration[5.1]
  def change
    create_table :archive_preserved_copy_parts do |t|
      t.bigint :size
      t.references :archive_preserved_copy, index: true, foreign_key: true, null: false

      t.timestamps
    end
  end
end
