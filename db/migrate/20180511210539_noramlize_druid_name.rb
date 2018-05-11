class NoramlizeDruidName < ActiveRecord::Migration[5.1]
  def change
    PreservedObject.normalize_druid_name
  end
end
