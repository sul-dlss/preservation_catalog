class RemoveStatusFromPreservationCopies < ActiveRecord::Migration[5.1]
  def change
    remove_column :preservation_copies, :status, :string
  end
end
