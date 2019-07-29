# frozen_string_literal: true

module Moab
  # Because some harmless getters on the object save us much tribulation and runaround
  class VerificationResult
    # @return [Hash<String => Hash>] nested Hash structure
    def subsets
      details.dig('group_differences', 'manifests', 'subsets') || {}
    end
  end
end
