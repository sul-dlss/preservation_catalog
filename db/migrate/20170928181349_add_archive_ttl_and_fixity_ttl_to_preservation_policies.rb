class AddArchiveTtlAndFixityTtlToPreservationPolicies < ActiveRecord::Migration[5.1]
  def change
    add_column :preservation_policies, :archive_ttl, :integer, null: false
    add_column :preservation_policies, :fixity_ttl, :integer, null: false
  end
end
