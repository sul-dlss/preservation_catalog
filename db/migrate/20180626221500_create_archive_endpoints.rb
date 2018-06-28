class CreateArchiveEndpoints < ActiveRecord::Migration[5.1]
  def change
    create_table :archive_endpoints do |t|
      t.string :endpoint_name, null: false
      t.integer :delivery_class, null: false
      t.string :endpoint_node
      t.string :storage_location

      t.timestamps

      t.index :endpoint_name, unique: true
    end
  end
end
