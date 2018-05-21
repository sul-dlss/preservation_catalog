class RemoveAccessKeyFromEndpoints < ActiveRecord::Migration[5.1]
  def change
    remove_column :endpoints, :access_key, :string
  end
end
