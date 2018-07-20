##
# PreservedCopy represents a concrete instance of a PreservedObject version, in physical storage on some node.
class PreservedCopy < ApplicationRecord
  OK_STATUS = 'ok'.freeze
  INVALID_MOAB_STATUS = 'invalid_moab'.freeze
  INVALID_CHECKSUM_STATUS = 'invalid_checksum'.freeze
  ONLINE_MOAB_NOT_FOUND_STATUS = 'online_moab_not_found'.freeze
  UNEXPECTED_VERSION_ON_STORAGE_STATUS = 'unexpected_version_on_storage'.freeze
  VALIDITY_UNKNOWN_STATUS = 'validity_unknown'.freeze
  UNREPLICATED_STATUS = 'unreplicated'.freeze
  REPLICATED_COPY_NOT_FOUND_STATUS = 'replicated_copy_not_found'.freeze

  # @note Hash values cannot be modified without migrating any associated persisted data.
  # @see [enum docs] http://api.rubyonrails.org/classes/ActiveRecord/Enum.html
  # TODO: Port over statuses to archive pres_copy model
  enum status: {
    OK_STATUS => 0,
    INVALID_MOAB_STATUS => 1,
    INVALID_CHECKSUM_STATUS => 2,
    ONLINE_MOAB_NOT_FOUND_STATUS => 3,
    UNEXPECTED_VERSION_ON_STORAGE_STATUS => 4,
    VALIDITY_UNKNOWN_STATUS => 6,
    UNREPLICATED_STATUS => 7,
    REPLICATED_COPY_NOT_FOUND_STATUS => 8
  }

  belongs_to :preserved_object, inverse_of: :preserved_copies
  belongs_to :endpoint, inverse_of: :preserved_copies
  has_many :zipped_moab_versions, dependent: :restrict_with_exception, inverse_of: :preserved_copy

  delegate :s3_key, to: :druid_version_zip

  validates :endpoint, :preserved_object, :status, :version, presence: true
  # NOTE: size here is approximate and not used for fixity checking
  validates :size, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :by_endpoint_name, lambda { |endpoint_name|
    joins(:endpoint).where(endpoints: { endpoint_name: endpoint_name })
  }

  scope :by_storage_location, lambda { |storage_dir|
    joins(:endpoint).where(endpoints: { storage_location: storage_dir })
  }

  scope :by_druid, lambda { |druid|
    joins(:preserved_object).where(preserved_objects: { druid: druid })
  }

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

  # given a version, create any ZippedMoabVersion records for that version which don't yet exist for archive
  #  endpoints which implement the parent PreservedObject's PreservationPolicy.
  # @param archive_vers [Integer] the version for which archive preserved copies should be created.  must be between
  #   1 and this PreservedCopy's version (inclusive).  Because there's an ZippedMoabVersion for
  #   each version for each endpoint (whereas there is one PreservedCopy for an entire online Moab).
  # @return [Array<ZippedMoabVersion>] the ZippedMoabVersion records that were created
  def create_zipped_moab_versions!(archive_vers)
    unless archive_vers > 0 && archive_vers <= version
      raise ArgumentError, "archive_vers (#{archive_vers}) must be between 0 and version (#{version})"
    end

    params = ZipEndpoint.which_need_archive_copy(preserved_object.druid, archive_vers).map do |zep|
      { version: archive_vers, zip_endpoint: zep, status: 'unreplicated' }
    end
    zipped_moab_versions.create!(params)
  end

  # Send to asynchronous replication pipeline
  # @raise [RuntimeError] if object is unpersisted or too large (>=~10GB)
  # @todo reroute to large object pipeline instead of raise
  def replicate!
    raise 'PreservedCopy must be persisted' unless persisted?
    ZipmakerJob.perform_later(preserved_object.druid, version)
  end

  # Send to asynchronous checksum validation pipeline
  def validate_checksums!
    ChecksumValidationJob.perform_later(self)
  end

  def druid_version_zip
    @druid_version_zip ||= DruidVersionZip.new(preserved_object.druid, version)
  end

  def update_audit_timestamps(moab_validated, version_audited)
    t = Time.current
    self.last_moab_validation = t if moab_validated
    self.last_version_audit = t if version_audited
  end

  # @param [Boolean] moab_validated whether validation has been run (regardless of result)
  # @param [Integer] new_version
  # @param [Integer] new_size is expected to be numeric if provided
  def upd_audstamps_version_size(moab_validated, new_version, new_size = nil)
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
