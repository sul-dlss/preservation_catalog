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
end
