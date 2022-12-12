# frozen_string_literal: true

module Dashboard
  # methods for dashboard pertaining to ReplicationFlowComponent
  class ReplicationFlowComponent < ViewComponent::Base
    def zip_cache_retention_days
      # setting is in minutes, we want days
      Settings.zip_cache_expiry_time.to_i / 60 / 24
    end
  end
end
