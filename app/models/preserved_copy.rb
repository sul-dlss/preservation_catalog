##
# PreservedCopy represents a concrete instance of a PreservedObject, in physical storage on some node.
class PreservedCopy < ApplicationRecord
  enum status: {
    ok: 0,
    invalid_moab: 1,
    invalid_checksum: 2,
    online_moab_not_found: 3,
    expected_version_not_found_online: 4,
    fixity_check_failed: 5
  }

  DEFAULT_STATUS = 'ok'.freeze

  belongs_to :preserved_object
  belongs_to :endpoint

  validates :endpoint, presence: true
  validates :preserved_object, presence: true
  # NOTE: size here is approximate and not used for fixity checking
  validates :size, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :status, inclusion: { in: statuses.keys }
  validates :version, presence: true
end
