class AddAuditTimestampsToPreservedCopies < ActiveRecord::Migration[5.1]
  def change
    rename_column :preserved_copies, :last_checked_on_storage, :last_moab_validation
    add_index :preserved_copies, :last_moab_validation
    add_column :preserved_copies, :last_version_audit, :datetime
    add_index :preserved_copies, :last_version_audit
    add_index :preserved_copies, :last_checksum_validation
    remove_column :preserved_copies, :last_audited, :bigint
  end
end
