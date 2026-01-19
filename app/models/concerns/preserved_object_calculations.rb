# frozen_string_literal: true

# Methods for calculating aggregations on PreservedObjects.
# These are separated from the main PreservedObject class for clarity.
module PreservedObjectCalculations
  extend ActiveSupport::Concern
  include InstrumentationSupport

  class_methods do
    # @return [Integer] count of PreservedObjects with expired archive audits with grace period
    def expired_archive_audit_with_grace_count
      where(last_archive_audit: ...(Time.current - Settings.preservation_policy.archive_ttl.seconds - 7.days))
        .annotate(caller)
        .count
    end
  end
end
