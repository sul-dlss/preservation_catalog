class AddAuditFieldsToPreservedObject < ActiveRecord::Migration[8.0]
  def change
    add_column :preserved_objects, :last_moab_validation, :datetime
    add_column :preserved_objects, :last_checksum_validation, :datetime
    add_column :preserved_objects, :last_version_audit, :datetime
    add_column :preserved_objects, :status, :integer
    add_column :preserved_objects, :status_details, :string
    add_column :preserved_objects, :size, :bigint
    add_column :preserved_objects, :from_moab_storage_root_id, :bigint
    add_column :preserved_objects, :moab_storage_root_id, :bigint

    add_index :preserved_objects, :last_moab_validation
    add_index :preserved_objects, :last_checksum_validation
    add_index :preserved_objects, :last_version_audit
    add_index :preserved_objects, :status
    add_index :preserved_objects, :from_moab_storage_root_id
    add_index :preserved_objects, :moab_storage_root_id

    add_index :preserved_objects, [:moab_storage_root_id, :current_version], unique: true, name: 'index_preserved_objects_on_storage_root_and_version'
    add_index :preserved_objects, [:moab_storage_root_id], unique: true, name: 'index_preserved_objects_on_storage_root_id'

    add_foreign_key :preserved_objects, :moab_storage_roots, column: :from_moab_storage_root_id
    add_foreign_key :preserved_objects, :moab_storage_roots
  end
end
