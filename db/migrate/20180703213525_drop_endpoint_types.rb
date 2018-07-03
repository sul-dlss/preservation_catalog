class DropEndpointTypes < ActiveRecord::Migration[5.1]
  def change
    remove_column :endpoints, :endpoint_type_id
    drop_table :endpoint_types
  end
end
