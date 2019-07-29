# frozen_string_literal: true

##
# defines some characteristics about how an object should be preserved, or how an endpoint preserves objects
class PreservationPolicy < ApplicationRecord
  # NOTE: The time to live (ttl) fields stored in PreservationPolicy are Integer measurements in seconds
  has_many :preserved_objects, dependent: :restrict_with_exception
  has_and_belongs_to_many :moab_storage_roots
  has_and_belongs_to_many :zip_endpoints

  validates :preservation_policy_name, presence: true, uniqueness: true
  validates :archive_ttl, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :fixity_ttl, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # @return [PreservationPolicy] creates default record if necessary
  def self.default_policy
    find_or_create_by!(preservation_policy_name: default_name) do |preservation_policy|
      preservation_policy.archive_ttl = 7_776_000 # 90 days
      preservation_policy.fixity_ttl = 7_776_000 # 90 days
    end
  end

  def self.default_name
    'default'
  end
end
