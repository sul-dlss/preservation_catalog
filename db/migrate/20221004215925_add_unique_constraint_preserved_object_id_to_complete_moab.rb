class AddUniqueConstraintPreservedObjectIdToCompleteMoab < ActiveRecord::Migration[6.1]
  def up
    remove_index :complete_moabs, :name=> "index_complete_moabs_on_preserved_object_id"
    add_index :complete_moabs, [:preserved_object_id], :unique => true, :name=> "index_complete_moabs_on_preserved_object_id"
  end

  def down
    remove_index :complete_moabs, :name=> "index_complete_moabs_on_preserved_object_id"
    add_index :complete_moabs, [:preserved_object_id], :name=> "index_complete_moabs_on_preserved_object_id"
  end
end
