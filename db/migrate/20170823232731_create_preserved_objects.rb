class CreatePreservedObjects < ActiveRecord::Migration[5.1]
  def change
    create_table :preserved_objects do |t|
      t.string :druid, null: false, unique: true
      t.integer :version
      t.string :preservation_policy
      t.integer :size

      t.timestamps
    end

    add_index :preserved_objects, :druid
    add_index :preserved_objects, :preservation_policy
  end
end
