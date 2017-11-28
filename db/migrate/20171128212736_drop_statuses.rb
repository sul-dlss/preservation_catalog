class DropStatuses < ActiveRecord::Migration[5.1]
  def change
    drop_table :statuses
  end
end
