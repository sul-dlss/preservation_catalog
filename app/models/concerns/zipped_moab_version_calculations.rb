# frozen_string_literal: true

# Methods for calculating aggregations on ZippedMoabVersions.
# These are separated from the main MoabRecord class for clarity.
module ZippedMoabVersionCalculations
  extend ActiveSupport::Concern
  include InstrumentationSupport

  STUCK_STATUSES = %w[created incomplete].freeze

  included do
    # @return [ActiveRecord::Relation<ZippedMoabVersion>] ZippedMoabVersions with failed status
    scope :with_errors, -> { where(status: 'failed').annotate(caller) }

    # @return [ActiveRecord::Relation<ZippedMoabVersion>] ZippedMoabVersions with status of incomplete or created for more than a week
    scope :stuck, lambda {
      where(status: STUCK_STATUSES)
        .where(status_updated_at: ...1.week.ago)
        .annotate(caller)
    }
  end

  class_methods do
    # @return [Integer] count of ZippedMoabVersions with status of created
    def created_count
      where(status: 'created')
        .annotate(caller)
        .count
    end

    # @return [Integer] count of ZippedMoabVersions with status of incomplete
    def incomplete_count
      where(status: 'incomplete')
        .annotate(caller)
        .count
    end

    # @return [Integer] count of missing ZippedMoabVersions
    def missing_count
      (PreservedObject.sum(:current_version) * ZipEndpoint.count) - count
    end
  end
end
