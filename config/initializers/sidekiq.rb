# frozen_string_literal: true

# See separate initializer for redis used by unique job.

# Note the increased timeouts to try to address Redis timeouts
Sidekiq.configure_server do |config|
  config.redis = { url: Settings.redis_url, network_timeout: Settings.redis_timeout, pool_timeout: Settings.redis_timeout }
  # For Sidekiq Pro
  config.super_fetch!
end

Sidekiq.configure_client do |config|
  config.redis = { url: Settings.redis_url, network_timeout: Settings.redis_timeout, pool_timeout: Settings.redis_timeout }
end
Sidekiq::Client.reliable_push! unless Rails.env.test?
