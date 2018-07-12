# Corresponds to a Moab-Version on an ArchiveEndpoint.
#   There will be individual parts (at least one) - see ArchivepreservedCopyPart.
# For a fully consistent system, given an (Online) PreservedCopy, the number of associated
# ArchivePreservedCopy objects should be:
#   pc.preserved_object.current_version * number_of_archive_endpoints
#
# @note Does not have size independent of part(s)
class ArchivePreservedCopy < ApplicationRecord
  belongs_to :preserved_copy
  belongs_to :archive_endpoint
  has_many :zip_parts, dependent: :destroy, inverse_of: :archive_preserved_copy
  delegate :preserved_object, to: :preserved_copy

  # @note Hash values cannot be modified without migrating any associated persisted data.
  # @see [enum docs] http://api.rubyonrails.org/classes/ActiveRecord/Enum.html
  enum status: {
    'ok' => 0,
    'unreplicated' => 1,
    'archive_not_found' => 2,
    'invalid_checksum' => 3
  }

  validates :archive_endpoint, presence: true
  validates :preserved_copy, presence: true
  validates :status, inclusion: { in: statuses.keys }
  validates :version, presence: true

  scope :by_druid, lambda { |druid|
    joins(preserved_copy: [:preserved_object]).where(preserved_objects: { druid: druid })
  }
end
