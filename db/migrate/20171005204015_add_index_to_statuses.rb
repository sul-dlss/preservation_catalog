class AddIndexToStatuses < ActiveRecord::Migration[5.1]
  def change
    add_index :statuses, :status_text, unique: true
  end
end
