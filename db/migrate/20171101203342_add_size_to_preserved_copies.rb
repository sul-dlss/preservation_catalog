class AddSizeToPreservedCopies < ActiveRecord::Migration[5.1]
  def change
    add_column :preserved_copies, :size, :bigint
  end
end
