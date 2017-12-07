##
# PreservedCopy represents a concrete instance of a PreservedObject, in physical storage on some node.
class PreservedCopy < ApplicationRecord
  OK_STATUS = 'ok'.freeze
  INVALID_MOAB_STATUS = 'invalid_moab'.freeze
  INVALID_CHECKSUM_STATUS = 'invalid_checksum'.freeze
  ONLINE_MOAB_NOT_FOUND_STATUS = 'online_moab_not_found'.freeze
  EXPECTED_VERS_NOT_FOUND_ON_STORAGE_STATUS = 'expected_vers_not_found_on_storage'.freeze
  FIXITY_CHECK_FAILED_STATUS = 'fixity_check_failed'.freeze
  DEFAULT_STATUS = OK_STATUS

  enum status: {
    OK_STATUS => 0,
    INVALID_MOAB_STATUS => 1,
    INVALID_CHECKSUM_STATUS => 2,
    ONLINE_MOAB_NOT_FOUND_STATUS => 3,
    EXPECTED_VERS_NOT_FOUND_ON_STORAGE_STATUS => 4,
    FIXITY_CHECK_FAILED_STATUS => 5
  }

  belongs_to :preserved_object
  belongs_to :endpoint

  validates :endpoint, presence: true
  validates :preserved_object, presence: true
  # NOTE: size here is approximate and not used for fixity checking
  validates :size, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :status, inclusion: { in: statuses.keys }
  validates :version, presence: true
end
