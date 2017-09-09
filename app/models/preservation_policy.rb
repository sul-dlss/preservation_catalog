##
# defines some characteristics about how an object should be preserved, or how an endpoint preserves objects
class PreservationPolicy < ApplicationRecord
  has_and_belongs_to_many :endpoints

  validates :preservation_policy_name, presence: true
end
