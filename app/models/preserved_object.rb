##
# PreservedObject represents a master record tying together all
# concrete copies of an object that is being preserved.  It does not
# represent a specific stored instance on a specific node, but aggregates
# those instances.
class PreservedObject < ApplicationRecord
  has_many :preservation_copies
  validates :druid, presence: true, uniqueness: true
  validates :current_version, presence: true
end
