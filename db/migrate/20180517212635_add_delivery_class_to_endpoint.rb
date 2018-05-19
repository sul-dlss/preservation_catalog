class AddDeliveryClassToEndpoint < ActiveRecord::Migration[5.1]
  def change
    add_column :endpoints, :delivery_class, :int
  end
end
