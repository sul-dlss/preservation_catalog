class CreatePreservedObjects < ActiveRecord::Migration[5.1]
  def change
    create_table :preserved_objects do |t|
      t.string :druid, null: false, unique: true, index: true
      t.integer :current_version, null: false
      t.string :preservation_policy, index: true
      t.integer :size

      t.timestamps
    end
  end
end
