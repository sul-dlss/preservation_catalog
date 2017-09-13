class CreateEndpointTypes < ActiveRecord::Migration[5.1]
  def change
    create_table :endpoint_types do |t|
      t.string :type_name, null: false, unique: true
      t.string :endpoint_class, null: false

      t.timestamps
    end
  end
end
