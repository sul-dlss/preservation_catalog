class AddDetailsToEndpoints < ActiveRecord::Migration[5.1]
  def change
    add_column :endpoints, :endpoint_node, :string, null: false
    add_column :endpoints, :storage_location, :string, null: false
    add_column :endpoints, :recovery_cost, :int, null: false
    add_column :endpoints, :access_key, :string
  end
end
