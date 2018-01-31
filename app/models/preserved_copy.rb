##
# PreservedCopy represents a concrete instance of a PreservedObject, in physical storage on some node.
class PreservedCopy < ApplicationRecord
  OK_STATUS = 'ok'.freeze
  INVALID_MOAB_STATUS = 'invalid_moab'.freeze
  INVALID_CHECKSUM_STATUS = 'invalid_checksum'.freeze
  ONLINE_MOAB_NOT_FOUND_STATUS = 'online_moab_not_found'.freeze
  EXPECTED_VERS_NOT_FOUND_ON_STORAGE_STATUS = 'unexpected_version_on_storage'.freeze
  VALIDITY_UNKNOWN_STATUS = 'validity_unknown'.freeze

  # NOTE:  DO NOT change the underlying constants for enum values that have been merged to
  # master/used in prod db (or at least, consider the necessary migration)
  enum status: {
    OK_STATUS => 0,
    INVALID_MOAB_STATUS => 1,
    INVALID_CHECKSUM_STATUS => 2,
    ONLINE_MOAB_NOT_FOUND_STATUS => 3,
    EXPECTED_VERS_NOT_FOUND_ON_STORAGE_STATUS => 4,
    VALIDITY_UNKNOWN_STATUS => 6
  }

  belongs_to :preserved_object
  belongs_to :endpoint

  validates :endpoint, presence: true
  validates :preserved_object, presence: true
  # NOTE: size here is approximate and not used for fixity checking
  validates :size, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :status, inclusion: { in: statuses.keys }
  validates :version, presence: true

  def update_audit_timestamps(moab_validated, version_audited)
    t = Time.current
    self.last_moab_validation = t if moab_validated
    self.last_version_audit = t if version_audited
  end

  # moab_validated must not be nil. boolean indicating whether validation has been run (regardless of result).
  # new_version is expected to be numeric
  # new_size is expected to be numeric if provided (nil is allowed)
  def upd_audstamps_version_size(moab_validated, new_version, new_size)
    self.version = new_version
    self.size = new_size if new_size
    update_audit_timestamps(moab_validated, true)
  end

  def update_status(new_status)
    return unless new_status != status
    yield
    self.status = new_status
  end

  def matches_po_current_version?
    version == preserved_object.current_version
  end
end
