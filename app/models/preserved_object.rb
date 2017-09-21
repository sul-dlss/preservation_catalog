##
# PreservedObject represents a master record tying together all
# concrete copies of an object that is being preserved.  It does not
# represent a specific stored instance on a specific node, but aggregates
# those instances.
class PreservedObject < ApplicationRecord
  # NOTE: The size field stored in PreservedObject is approximate,as it is determined from size
  # on disk (which can vary from machine to machine). This field value should not be used for
  # fixity checking!
  belongs_to :preservation_policy
  has_many :preservation_copies
  validates :druid, presence: true, uniqueness: true
  validates :current_version, presence: true
  validates :preservation_policy, null: false

  def self.update_or_create(druid, current_version: nil, size: nil, preservation_policy: nil)
    existing_rec = find_by(druid: druid)
    if exists?(druid: druid)
      # TODO: add more info, e.g. caller, timestamp written to db
      Rails.logger.debug "update #{druid} called and object exists"

      existing_rec.update_if_valid_version_change(druid, current_version, size) if current_version

      if existing_rec.changed?
        existing_rec.save
      else
        existing_rec.touch
      end

      true
    else
      Rails.logger.warn "update #{druid} called but object not found; writing object" # TODO: add more info
      create(druid: druid, current_version: current_version, size: size, preservation_policy: preservation_policy)
      false
    end
  end

  def update_if_valid_version_change(druid, updated_version, size)
    version_comparison = self.current_version <=> updated_version
    if version_comparison.zero?
      Rails.logger.info "#{druid} incoming version is equal to db version"
    elsif version_comparison == 1
      # TODO: needs manual intervention until automatic recovery services implemented
      Rails.logger.error "#{druid} incoming version smaller than db version"
    elsif version_comparison == -1
      Rails.logger.info "#{druid} incoming version is greater than db version"
      self.current_version = updated_version
      self.size = size if size
    end
  end
end
