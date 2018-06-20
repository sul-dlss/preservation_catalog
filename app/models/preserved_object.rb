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

  # given a version, create any PreservedCopy records for that version which don't yet exist for archive
  #  endpoints which implement this PreservedObject's PreservationPolicy.
  # @param archive_vers [Integer] the version for which preserved copies should be created.  must be between
  #   1 and this PreservedObject's current version (inclusive).
  # @return [Array<PreservedCopy>] the PreservedCopy records that were created
  def create_archive_preserved_copies(archive_vers)
    unless archive_vers > 0 && archive_vers <= current_version
      raise ArgumentError, "archive_vers (#{archive_vers}) must be between 0 and current_version (#{current_version})"
    end

    params = Endpoint.which_need_archive_copy(druid, archive_vers).map do |ep|
      { version: archive_vers, endpoint: ep, status: PreservedCopy::UNREPLICATED_STATUS }
    end
    preserved_copies.create!(params)
  end
end
