require 'resque/failure/redis_multi_queue'

# load environment specific configuration
config_file = Rails.root.join('config', 'resque.yml')
resque_config = YAML.safe_load(ERB.new(IO.read(config_file)).result)
Resque.redis = resque_config[Rails.env.to_s]

# configure a separate failure queue per job queue
Resque::Failure.backend = Resque::Failure::RedisMultiQueue
