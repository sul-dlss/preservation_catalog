class RenameCurrentVersionToVersionInPreservedCopies < ActiveRecord::Migration[5.1]
  def change
    rename_column :preserved_copies, :current_version, :version
  end
end
