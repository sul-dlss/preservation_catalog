##
# defines some characteristics about how an object should be preserved, or how an endpoint preserves objects
class PreservationPolicy < ApplicationRecord
  # NOTE: The time to live (ttl) fields stored in PreservationPolicy are Integer measurements in seconds
  has_many :preserved_objects, dependent: :restrict_with_exception
  has_and_belongs_to_many :endpoints

  validates :preservation_policy_name, presence: true, uniqueness: true
  validates :archive_ttl, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :fixity_ttl, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # this is a *very* naive cache eviction algorithm: if any pres policy changes, clear
  # the cache.  we expect pres policies to change very infrequently, so probably no big deal.
  # we can get smarter if/when we need to.
  after_save { |_record| self.class.send(:clear_id_cache) }

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
    find_by!(preservation_policy_name: Settings.preservation_policies.default_policy_name)
  end

  # note that this is cached.  prefer calling this method over .default_policy if an id
  # will suffice (e.g., you only need the id, not the whole object, to set an association
  # to a pres policy on another ActiveRecord object).
  def self.default_policy_id
    id_cache[:default_policy_id] ||= default_policy.id
  end

  private_class_method def self.id_cache
    @id_cache ||= {}
  end

  private_class_method def self.clear_id_cache
    @id_cache = {}
  end
end
