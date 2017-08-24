##
# PreservationCopy represents a concrete instance of a PreservedObject, in physical storage on some node.
class PreservationCopy < ApplicationRecord
  belongs_to :preserved_object
  belongs_to :endpoint
  validates :preserved_object, presence: true
  validates :endpoint, presence: true
  validates :current_version, presence: true
end
