class RenamePreservationCopiesToPreservedCopies < ActiveRecord::Migration[5.1]
  def change
    rename_table :preservation_copies, :preserved_copies
  end
end
