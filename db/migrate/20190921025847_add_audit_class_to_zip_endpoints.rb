class AddAuditClassToZipEndpoints < ActiveRecord::Migration[5.1]
  def up
    add_column :zip_endpoints, :audit_class, :integer

    execute <<-SQL
      UPDATE zip_endpoints
      SET audit_class = 1
      WHERE delivery_class in (1, 2);

      UPDATE zip_endpoints
      SET audit_class = 2
      WHERE delivery_class = 3;
    SQL

    change_column :zip_endpoints, :audit_class, :integer, null: false
  end

  def down
    remove_column :zip_endpoints, :audit_class
  end
end
