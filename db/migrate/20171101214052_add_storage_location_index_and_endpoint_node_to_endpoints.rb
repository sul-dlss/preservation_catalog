class AddStorageLocationIndexAndEndpointNodeToEndpoints < ActiveRecord::Migration[5.1]
  def change
    add_index :endpoints, :storage_location
    add_index :endpoints, :endpoint_node
  end
end
