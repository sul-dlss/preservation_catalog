class CreateEndpointsPreservationPolicies < ActiveRecord::Migration[5.1]
  def change
    create_table :endpoints_preservation_policies do |t|
      t.references :preservation_policy, foreign_key: true, null: false
      t.references :endpoint, foreign_key: true, null: false
    end
  end
end
