# frozen_string_literal: true

# Methods for calculating aggregations on MoabRecords.
# These are separated from the main MoabRecord class for clarity.
module MoabRecordCalculations
  extend ActiveSupport::Concern
  include InstrumentationSupport

  ERROR_STATUSES = %w[invalid_moab
                      invalid_checksum
                      moab_on_storage_not_found
                      unexpected_version_on_storage].freeze

  included do
    # @return [ActiveRecord::Relation<MoabRecord>] MoabRecords with error statuses
    scope :with_errors, -> { where(status: ERROR_STATUSES).annotate(caller) }

    # @return [ActiveRecord::Relation<MoabRecord>] MoabRecords with status of validity_unknown for more than a week
    scope :stuck, lambda {
      where(status: 'validity_unknown').where(updated_at: ...1.week.ago).annotate(caller)
    }
  end

  class_methods do
    # @return [Integer] count of MoabRecords with status of validity_unknown
    def validity_unknown_count
      where(status: 'validity_unknown')
        .annotate(caller)
        .count
    end

    # @return [Integer] count of MoabRecords with checksum validation audits with grace period
    def expired_checksum_validation_with_grace_count
      where(last_checksum_validation: ...(Time.current - Settings.preservation_policy.fixity_ttl.seconds - 7.days))
        .annotate(caller)
        .count
    end
  end
end
