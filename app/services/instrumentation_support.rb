# frozen_string_literal: true

# Methods to support instrumentation
module InstrumentationSupport
  # Provides a source annotation for logging queries.
  # Example: storage_root.moab_records.annotate(source_annotation).sum(:size)
  # See lib/slow_query_logger.rb
  def caller
    # No-op if slow queries are not enabled
    return unless Settings.slow_queries.enable

    location = Kernel.caller_locations(2, 1).first
    path = location.path.delete_prefix("#{Rails.root}/")

    "source=#{path}:#{location.lineno} in #{location.base_label}"
  end
end
