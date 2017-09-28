##
# defines some characteristics about how an object should be preserved, or how an endpoint preserves objects
class PreservationPolicy < ApplicationRecord
  # NOTE: The time to live (ttl) fields stored in PreservationPolicy are Integer measurements in seconds
  has_many :preserved_objects
  has_and_belongs_to_many :endpoints

  validates :preservation_policy_name, presence: true
  validates :archive_ttl, presence: true
  validates :fixity_ttl, presence: true
end
