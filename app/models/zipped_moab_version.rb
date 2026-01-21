# frozen_string_literal: true

# Corresponds to a Moab-Version on a ZipEndpoint.
#   There will be individual parts (at least one) - see ZipPart.
# For a fully consistent system, given a PreservedObject, the number of associated
# ZippedMoabVersion objects should be:
#   preserved_object.current_version * ZipEndpoint.count
#
# @note Does not have size independent of part(s), see `#total_part_size`
class ZippedMoabVersion < ApplicationRecord
  belongs_to :preserved_object, inverse_of: :zipped_moab_versions
  belongs_to :zip_endpoint, inverse_of: :zipped_moab_versions
  has_many :zip_parts, dependent: :restrict_with_exception, inverse_of: :zipped_moab_version

  validates :version, presence: true

  # If zip_parts_count is present, must be greater than zero
  validates :zip_parts_count, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  enum :status, {
    'ok' => 0,
    'incomplete' => 1,
    'created' => 2, # DB-level default. The ZippedMoabVersion has been created, but no ZipParts yet.
    'failed' => 3
  }

  delegate :druid, to: :preserved_object

  scope :by_druid, lambda { |druid|
    joins(:preserved_object).where(preserved_objects: { druid: druid })
  }

  before_save :update_status_updated_at
  before_save :update_status_details

  def total_part_size
    zip_parts.sum(&:size)
  end

  def update_status_updated_at
    self.status_updated_at = Time.current if status_changed?
  end

  def update_status_details
    # Clear status_details if status changed but status_details did not
    self.status_details = nil if status_changed? && !status_details_changed?
  end

  def druid_version_zip
    @druid_version_zip ||= Replication::DruidVersionZip.new(
      # In tests, a PreservedObject may not have a MoabRecord, hence the safe navigation.
      preserved_object.druid, version, preserved_object&.moab_record&.moab_storage_root&.storage_location # rubocop:disable Style/SafeNavigationChainLength
    )
  end
end
