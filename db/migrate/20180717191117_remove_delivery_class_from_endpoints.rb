class RemoveDeliveryClassFromEndpoints < ActiveRecord::Migration[5.1]
  def change
    remove_column :endpoints, :delivery_class, :integer
  end
end
