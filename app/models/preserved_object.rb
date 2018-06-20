##
# PreservedObject represents a master record tying together all
# concrete copies of an object that is being preserved.  It does not
# represent a specific stored instance on a specific node, but aggregates
# those instances.
class PreservedObject < ApplicationRecord
  PREFIX_RE = /druid:/i
  belongs_to :preservation_policy
  has_many :preserved_copies, dependent: :restrict_with_exception
  validates :druid,
            presence: true,
            uniqueness: true,
            length: { is: 11 },
            format: { with: /(?!#{PREFIX_RE})#{DruidTools::Druid.pattern}/ } # ?! group is a *negative* match
  validates :current_version, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :preservation_policy, null: false

  # Create any needed archive PreservedCopy records which don't yet exist.
  # Backfills for previous versions, because preservation_policy applies to the whole object, not versions.
  # More pragmatically, only having (e.g.) v4 of a Moab is not enough to rebuild it!
  # @return [Array<PreservedCopy>] the PreservedCopy records that were created
  def create_archive_preserved_copies!
    params = Endpoint.ids_to_versions_found(druid).map do |ep, versions|
      missing = expected_versions.to_a - versions
      next if missing.empty?
      missing.map { |v| { version: v, endpoint_id: ep, status: 'unreplicated' } }
    end.flatten.compact
    preserved_copies.create!(params)
  end

  # @return [Enumerable<Integer>]
  def expected_versions
    1..current_version
  end
end
