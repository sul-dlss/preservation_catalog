##
# PreservedObject represents a master record tying together all
# concrete copies of an object that is being preserved.  It does not
# represent a specific stored instance on a specific node, but aggregates
# those instances.
class PreservedObject < ApplicationRecord
  belongs_to :preservation_policy
  has_many :preserved_copies, dependent: :restrict_with_exception
  validates :druid, presence: true, uniqueness: true, format: { with: DruidTools::Druid.pattern }
  validates :current_version, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :preservation_policy, null: false

  def self.normalize_druid_name
    targets = PreservedObject.where("druid LIKE 'druid:%'")
    druids_no_prefix = targets.pluck(:druid).map { |d| d.split(':', 2).last }
    targets_by_druid = targets.map { |rec| [rec.druid, rec] }.to_h
    PreservedObject.where(druid: druids_no_prefix).pluck(:druid).each do |x|
      po = targets_by_druid.delete("druid:#{x}")
      ApplicationRecord.transaction do
        po.preserved_copies.destroy_all
        po.destroy
      end
    end
    targets_by_druid.each_value do |po|
      po.druid = po.druid.split(':', 2).last
      po.save!
    end
  end

  # given a version, create any PreservedCopy records for that version which don't yet exist for archive
  #  endpoints which implement this PreservedObject's PreservationPolicy.
  # @param archive_vers [Integer] the version for which preserved copies should be created.  must be between
  #   1 and this PreservedObject's current version (inclusive).
  # @return [Array<PreservedCopy>] the PreservedCopy records that were created
  def create_archive_preserved_copies(archive_vers)
    unless archive_vers > 0 && archive_vers <= current_version
      raise ArgumentError, "archive_vers (#{archive_vers}) must be between 0 and current_version (#{current_version})"
    end

    ApplicationRecord.transaction do
      Endpoint.which_need_archive_copy(druid, archive_vers).map do |ep|
        # TODO: remember to update size at some later point, after zip is created
        PreservedCopy.create!(
          preserved_object: self, version: archive_vers, endpoint: ep, status: PreservedCopy::UNREPLICATED_STATUS
        )
      end
    end
  end
end
