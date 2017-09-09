class RemoveEndpointTypeFromEndpoint < ActiveRecord::Migration[5.1]
  def change
    remove_column :endpoints, :endpoint_type, :string
  end
end
