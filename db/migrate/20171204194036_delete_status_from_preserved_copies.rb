class DeleteStatusFromPreservedCopies < ActiveRecord::Migration[5.1]
  def change
    remove_reference :preserved_copies, :status, index: true, foreign_key: true
  end
end