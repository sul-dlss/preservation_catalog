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

  class << self
    attr_writer :default_policy
  end

  # this is a *very* naive cache eviction algorithm: if any pres policy changes, clear
  # the cache.  we expect pres policies to change very infrequently, so probably no big deal.
  # we can get smarter if/when we need to.
  after_save { |_record| self.class.default_policy = nil }

  # iterates over the preservation policies enumerated in the settings, creating any that don't already exist.
  # @return [Array<PreservationPolicy>] the PreservationPolicy list for the preservation policies defined in the
  #   config (all entries, including any entries that may have been seeded already).
  # @note this adds new entries from the config, and leaves existing entries alone, but won't delete anything.
  # TODO: figure out deletion/update based on config?
  def self.seed_from_config
    Settings.preservation_policies.policy_definitions.map do |policy_name, policy_config|
      find_or_create_by!(preservation_policy_name: policy_name.to_s) do |preservation_policy|
        preservation_policy.archive_ttl = policy_config.archive_ttl
        preservation_policy.fixity_ttl = policy_config.fixity_ttl
      end
    end
  end

  def self.default_policy
    @default_policy ||= find_by!(preservation_policy_name: Settings.preservation_policies.default_policy_name)
  end
end
