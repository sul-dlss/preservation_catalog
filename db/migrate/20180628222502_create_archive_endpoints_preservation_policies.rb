class CreateArchiveEndpointsPreservationPolicies < ActiveRecord::Migration[5.1]
  def change
    create_table :archive_endpoints_preservation_policies do |t|
      t.references :preservation_policy, foreign_key: true, null: false, index: { name: 'index_archive_endpoints_pres_policies_on_pres_policy_id' }
      t.references :archive_endpoint, foreign_key: true, null: false, index: { name: 'index_archive_endpoints_pres_policies_on_archive_endpoint_id' }
    end
  end
end
