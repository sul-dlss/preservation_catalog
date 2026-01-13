class DropDeliveryClassFromZipEndpoints < ActiveRecord::Migration[8.0]
  def change
    remove_column :zip_endpoints, :delivery_class, :integer
  end
end
