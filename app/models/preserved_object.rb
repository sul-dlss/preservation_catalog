# frozen_string_literal: true

##
# PreservedObject represents a master record tying together all
# concrete copies of an object that is being preserved.  It does not
# represent a specific stored instance on a specific node, but aggregates
# those instances.
class PreservedObject < ApplicationRecord
  PREFIX_RE = /druid:/i.freeze
  belongs_to :preservation_policy
  has_many :complete_moabs, dependent: :restrict_with_exception, autosave: true
  validates :druid,
            presence: true,
            uniqueness: true,
            length: { is: 11 },
            format: { with: /(?!#{PREFIX_RE})#{DruidTools::Druid.pattern}/ } # ?! group is a *negative* match
  validates :current_version, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :preservation_policy, null: false

  scope :without_complete_moabs, -> { left_outer_joins(:complete_moabs).where(complete_moabs: { id: nil }) }

  def as_json(*)
    super.except('id', 'preservation_policy_id')
  end
end
