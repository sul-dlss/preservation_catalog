class CreateEndpoints < ActiveRecord::Migration[5.1]
  def change
    create_table :endpoints do |t|
      t.string :endpoint_name, null: false, unique: true, index: true
      t.string :endpoint_type, null: false, index: true # `type` is a reserved column name

      t.timestamps
    end

  end
end
