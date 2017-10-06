class AddIndexToEndpoints < ActiveRecord::Migration[5.1]
  def change
    remove_index :endpoints, :endpoint_name
    add_index :endpoints, :endpoint_name, unique: true
  end
end
