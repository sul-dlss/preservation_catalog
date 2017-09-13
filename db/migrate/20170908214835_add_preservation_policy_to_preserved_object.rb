class AddPreservationPolicyToPreservedObject < ActiveRecord::Migration[5.1]
  def change
    add_reference :preserved_objects, :preservation_policy, foreign_key: true, index: true, null: false
  end
end
