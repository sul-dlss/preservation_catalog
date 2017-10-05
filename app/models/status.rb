##
# the current status of a preservation copy, e.g. all good, fixity check failed, etc
class Status < ApplicationRecord
  has_many :preservation_copies
  validates :status_text, presence: true, uniqueness: true

  # iterates over the statuses enumerated in the settings, creating any that don't already exist.
  # returns an array with the result of the ActiveRecord find_or_create_by! call for each settings entry (i.e.,
  # the Status rows defined in the config, whether newly created by this call, or previously created).
  # NOTE: this adds new entries from the config, and leaves existing entries alone, but won't delete anything.
  # TODO: figure out deletion based on config?
  def self.seed_from_config
    Settings.statuses.map do |status_text|
      Status.find_or_create_by!(status_text: status_text)
    end
  end
end
