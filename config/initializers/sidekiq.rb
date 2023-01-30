# frozen_string_literal: true

Sidekiq.configure_server do |config|
  config.redis = { url: Settings.redis_url }
  # For Sidekiq Pro
  config.super_fetch!
end

Sidekiq.configure_client do |config|
  config.redis = { url: Settings.redis_url }
end
Sidekiq::Client.reliable_push! unless Rails.env.test?
