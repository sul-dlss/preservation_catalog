class NoramlizeDruidName < ActiveRecord::Migration[5.1]
  def change
    # No longer possible to create invalid data as fixed by this removed method.
    # PreservedObject.normalize_druid_name
  end
end
