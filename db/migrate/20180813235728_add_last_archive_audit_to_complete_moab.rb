class AddLastArchiveAuditToCompleteMoab < ActiveRecord::Migration[5.1]
  def change
    add_column :complete_moabs, :last_archive_audit, :datetime
    add_index :complete_moabs, :last_archive_audit
  end
end
