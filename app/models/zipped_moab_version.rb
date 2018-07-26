# Corresponds to a Moab-Version on a ZipEndpoint.
#   There will be individual parts (at least one) - see ZipPart.
# For a fully consistent system, given a PreservedCopy, the number of associated
# ZippedMoabVersion objects should be:
#   pc.preserved_object.current_version * number_of_zip_endpoints
#
# @note Does not have size independent of part(s)
class ZippedMoabVersion < ApplicationRecord
  belongs_to :preserved_copy, inverse_of: :zipped_moab_versions
  belongs_to :zip_endpoint, inverse_of: :zipped_moab_versions
  has_many :zip_parts, dependent: :destroy, inverse_of: :zipped_moab_version
  has_one :preserved_object, through: :preserved_copy, dependent: :restrict_with_exception

  # Note: In the context of creating many ZMV rows, this may *attempt* to queue the same druid/version multiple times,
  # but queue locking easily prevents duplicates (and the job is idempotent anyway).
  after_create :replicate!

  # @note Hash values cannot be modified without migrating any associated persisted data.
  # @see [enum docs] http://api.rubyonrails.org/classes/ActiveRecord/Enum.html
  enum status: {
    'ok' => 0,
    'unreplicated' => 1,
    'archive_not_found' => 2,
    'invalid_checksum' => 3
  }

  validates :preserved_copy, :status, :version, :zip_endpoint, presence: true

  scope :by_druid, lambda { |druid|
    joins(preserved_copy: [:preserved_object]).where(preserved_objects: { druid: druid })
  }

  # Send to asynchronous replication pipeline
  # @return [ZipmakerJob, false] false if unpersisted or parent PC has non-replicatable status
  def replicate!
    return false unless persisted? && preserved_copy.replicatable_status?
    ZipmakerJob.perform_later(preserved_object.druid, version)
  end
end
