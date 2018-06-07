##
# PreservedCopy represents a concrete instance of a PreservedObject, in physical storage on some node.
class PreservedCopy < ApplicationRecord
  OK_STATUS = 'ok'.freeze
  INVALID_MOAB_STATUS = 'invalid_moab'.freeze
  INVALID_CHECKSUM_STATUS = 'invalid_checksum'.freeze
  ONLINE_MOAB_NOT_FOUND_STATUS = 'online_moab_not_found'.freeze
  UNEXPECTED_VERSION_ON_STORAGE_STATUS = 'unexpected_version_on_storage'.freeze
  VALIDITY_UNKNOWN_STATUS = 'validity_unknown'.freeze
  UNREPLICATED_STATUS = 'unreplicated'.freeze

  # @note Hash values cannot be modified without migrating any associated persisted data.
  # @see [enum docs] http://api.rubyonrails.org/classes/ActiveRecord/Enum.html
  enum status: {
    OK_STATUS => 0,
    INVALID_MOAB_STATUS => 1,
    INVALID_CHECKSUM_STATUS => 2,
    ONLINE_MOAB_NOT_FOUND_STATUS => 3,
    UNEXPECTED_VERSION_ON_STORAGE_STATUS => 4,
    VALIDITY_UNKNOWN_STATUS => 6,
    UNREPLICATED_STATUS => 7
  }

  belongs_to :preserved_object
  belongs_to :endpoint
  has_many :zip_checksums, dependent: :restrict_with_exception

  validates :endpoint, presence: true
  validates :preserved_object, presence: true
  # NOTE: size here is approximate and not used for fixity checking
  validates :size, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :status, inclusion: { in: statuses.keys }
  validates :version, presence: true

  scope :by_endpoint_name, lambda { |endpoint_name|
    joins(:endpoint).where(endpoints: { endpoint_name: endpoint_name })
  }

  scope :by_storage_location, lambda { |storage_dir|
    joins(:endpoint).where(endpoints: { storage_location: storage_dir })
  }

  scope :by_druid, lambda { |druid|
    joins(:preserved_object).where(preserved_objects: { druid: druid })
  }

  scope :by_endpoint_class, lambda { |ec|
    joins(endpoint: [:endpoint_type]).where(endpoint_types: { endpoint_class: ec })
  }

  scope :for_archive_endpoints, -> { by_endpoint_class('archive') }
  scope :for_online_endpoints, -> { by_endpoint_class('online') }

  scope :least_recent_version_audit, lambda { |last_checked_b4_date|
    where('last_version_audit IS NULL or last_version_audit < ?', normalize_date(last_checked_b4_date))
      .order('last_version_audit IS NOT NULL, last_version_audit ASC')
    # possibly counter-intuitive: the .order sorts so that null values come first (because IS NOT NULL evaluates
    # to 0 for nulls, which sorts before 1 for non-nulls, which are then sorted by last_version_audit)
  }

  scope :fixity_check_expired, lambda {
    joins(:preserved_object)
      .joins(
        'INNER JOIN preservation_policies'\
        ' ON preservation_policies.id = preserved_objects.preservation_policy_id'\
        ' AND (last_checksum_validation + (fixity_ttl * INTERVAL \'1 SECOND\')) < CURRENT_TIMESTAMP'\
        ' OR last_checksum_validation IS NULL'
      )
      .order('last_checksum_validation IS NOT NULL, last_checksum_validation ASC')
    # possibly counter-intuitive: the .order sorts so that null values come first (because IS NOT NULL evaluates
    # to 0 for nulls, which sorts before 1 for non-nulls, which are then sorted by last_checksum_validation)
  }

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

  private_class_method def self.normalize_date(timestamp)
    return timestamp if timestamp.is_a?(Time) || timestamp.is_a?(ActiveSupport::TimeWithZone)
    Time.parse(timestamp).utc
  end
end
