class CreatePreservationPolicies < ActiveRecord::Migration[5.1]
  def change
    create_table :preservation_policies do |t|
      t.string :preservation_policy_name, null: false
    end
  end
end
