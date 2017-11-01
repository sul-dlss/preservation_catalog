##
# PreservedCopy represents a concrete instance of a PreservedObject, in physical storage on some node.
class PreservedCopy < ApplicationRecord
  belongs_to :preserved_object
  belongs_to :endpoint
  belongs_to :status

  validates :preserved_object, presence: true
  validates :endpoint, presence: true
  validates :current_version, presence: true
  validates :status, presence: true
  # NOTE: size here is approximate and not used for fixity checking
  validates :size, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

end
