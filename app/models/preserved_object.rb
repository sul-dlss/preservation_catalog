##
# PreservedObject represents a master record tying together all
# concrete copies of an object that is being preserved.  It does not
# represent a specific stored instance on a specific node, but aggregates
# those instances.
class PreservedObject < ApplicationRecord
  belongs_to :preservation_policy
  has_many :preservation_copies, dependent: :restrict_with_exception
  validates :druid, presence: true, uniqueness: true, format: { with: /\A[a-z]{2}\d{3}[a-z]{2}\d{4}\z/ }
  validates :current_version, presence: true, numericality: { only_integer: true, greater_than: 0 }
  # NOTE: size here is approximate and not used for fixity checking
  validates :size, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :preservation_policy, null: false
end
