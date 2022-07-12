# frozen_string_literal: true

require 'resque/failure/redis_multi_queue'

# load environment specific configuration
config_file = Rails.root.join('config', 'resque.yml')
resque_config = YAML.safe_load(ERB.new(File.read(config_file)).result)
redis_url = resque_config[Rails.env.to_s]
Resque.redis = redis_url

# configure a separate failure queue per job queue
Resque::Failure.backend = Resque::Failure::RedisMultiQueue

# see https://github.com/resque/resque/issues/1591#issuecomment-403805957
# this silences a deprecation warning that was hogging disk space
# and disrupting replication. Another suggested solution was pinning
# the resque gem to current master, but that didn't silence the warning
# compare https://travis-ci.org/sul-dlss/preservation_catalog/builds/420832575
# with    https://travis-ci.org/sul-dlss/preservation_catalog/builds/420830070
# the former monkeypatch branch shows no warnings, the latter, pinning, does
Redis::Namespace.class_eval do
  def client
    _client
  end
end
