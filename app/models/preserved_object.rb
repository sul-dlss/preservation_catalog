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

  def self.update(druid, current_version: nil, preservation_policy: nil)
    # TODO: Add , size: nil,  when we are going to use these variables.
    existing_rec = find_by(druid: druid)
    if exists?(druid: druid)
      # TODO: add more info, e.g. caller, timestamp written to db
      Rails.logger.debug "update #{druid} called and object exists"
      if current_version
        version_comparison = existing_rec.current_version <=> current_version
        update_entry_per_compare(version_comparison, existing_rec, druid, current_version)
      end
      true
    else
      create(druid: druid, current_version: current_version, preservation_policy: preservation_policy)
      Rails.logger.warn "update #{druid} called but object not found; writing object" # TODO: add more info
      false
    end
  end

  private_class_method
  def self.update_entry_per_compare(version_comparison, existing_rec, druid, current_version)
    if version_comparison.zero?
      Rails.logger.info "#{druid} incoming version is equal to db version"
      existing_rec.touch
    elsif version_comparison == 1
      # FIXME: what should happen
      Rails.logger.warn "#{druid} incoming version smaller than db version"
      existing_rec.touch
    elsif version_comparison == -1
      Rails.logger.info "#{druid} incoming version is greater than db version"
      existing_rec.current_version = current_version
      existing_rec.save
    end
  end
end
