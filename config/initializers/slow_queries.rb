# frozen_string_literal: true

# See lib/slow_query_logger.rb
if Settings.slow_queries.enable
  require 'slow_query_logger'

  # Setup the logger
  output = Rails.root.join('log/slow_queries.log')
  logger = SlowQueryLogger.new(output: output, threshold: Settings.slow_queries.threshold)

  # Subscribe to notifications
  ActiveSupport::Notifications.subscribe('sql.active_record', logger)
end
