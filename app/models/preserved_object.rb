##
# PreservedObject represents a master record tying together all
# concrete copies of an object that is being preserved.  It does not
# represent a specific stored instance on a specific node, but aggregates
# those instances.
class PreservedObject < ApplicationRecord
  PREFIX_RE = /druid:/i
  belongs_to :preservation_policy
  has_many :complete_moabs, dependent: :restrict_with_exception
  validates :druid,
            presence: true,
            uniqueness: true,
            length: { is: 11 },
            format: { with: /(?!#{PREFIX_RE})#{DruidTools::Druid.pattern}/ } # ?! group is a *negative* match
  validates :current_version, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :preservation_policy, null: false

  scope :without_complete_moabs, -> { left_outer_joins(:complete_moabs).where(complete_moabs: { id: nil }) }

  # Spawn asynchronous checks of all existing archive complete_moabs.
  # This logic is similar to PlexerJob, for a different purpose.
  # This should implement the start of the replication process if status is unreplicated for an archival comp_moab
  # Compare last_existence_check (from archive comp_moab) with archive TTL when checking the archival comp_moab status
  # Log an error message.
  # Calls ReplicatedFileCheckJob
  # This builds off of #917
  def check_zip_endpoints!
    # FIXME: STUB
    # Ticket: 920
  end
end
