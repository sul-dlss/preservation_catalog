##
# PreservedObject represents a master record tying together all
# concrete copies of an object that is being preserved.  It does not
# represent a specific stored instance on a specific node, but aggregates
# those instances.
class PreservedObject < ApplicationRecord
  # NOTE: The size field stored in PreservedObject is approximate,as it is determined from size
  # on disk (which can vary from machine to machine). This field value should not be used for
  # fixity checking!
  has_many :preservation_copies
  validates :druid, presence: true, uniqueness: true
  validates :current_version, presence: true
end
