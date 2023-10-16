# frozen_string_literal: true

pool_size = ENV.fetch('RAILS_MAX_THREADS', 5)

REDIS = ConnectionPool.new(size: pool_size) do
  Redis.new(url: Settings.redis_url, timeout: Settings.redis_timeout)
end
