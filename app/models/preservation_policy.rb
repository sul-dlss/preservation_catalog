##
# defines some characteristics about how an object should be preserved, or how an endpoint preserves objects
class PreservationPolicy < ApplicationRecord
  # NOTE: The time to live (ttl) fields stored in PreservationPolicy are Integer measurements in seconds
  has_many :preserved_objects, dependent: :restrict_with_exception
  has_and_belongs_to_many :endpoints

  validates :preservation_policy_name, presence: true
  validates :archive_ttl, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :fixity_ttl, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # iterates over the preservation policies enumerated in the settings, creating any that don't already exist.
  # returns an array with the result of the ActiveRecord find_or_create_by! call for each settings entry (i.e.,
  # the PreservationPolicy rows defined in the config, whether newly created by this call, or previously created).
  # NOTE: this adds new entries from the config, and leaves existing entries alone, but won't delete anything.
  # TODO: figure out deletion based on config?
  def self.seed_from_config
    Settings.preservation_policies.policy_definitions.map do |policy_name, policy_config|
      find_or_create_by!(preservation_policy_name: policy_name.to_s) do |preservation_policy|
        preservation_policy.archive_ttl = policy_config.archive_ttl
        preservation_policy.fixity_ttl = policy_config.fixity_ttl
      end
    end
  end

  def self.default_preservation_policy
    find_by!(preservation_policy_name: Settings.preservation_policies.default_policy_name)
  end
end
