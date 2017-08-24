class CreateEndpoints < ActiveRecord::Migration[5.1]
  def change
    create_table :endpoints do |t|
      t.string :endpoint_name, null: false, unique: true
      t.string :endpoint_type, null: false # `type` is a reserved column name

      t.timestamps
    end

    add_index :endpoints, :endpoint_name
    add_index :endpoints, :endpoint_type
  end
end
