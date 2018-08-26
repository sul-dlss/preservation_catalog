server 'preservation-catalog-prod-01.stanford.edu', user: 'pres', roles: %w[app db web]
server 'preservation-catalog-prod-02.stanford.edu', user: 'pres', roles: %w[app resque queue_populator]
server 'preservation-catalog-prod-03.stanford.edu', user: 'pres', roles: %w[app resque]
server 'preservation-catalog-prod-04.stanford.edu', user: 'pres', roles: %w[app resque cache_cleaner]

Capistrano::OneTimeKey.generate_one_time_key!
set :rails_env, 'production'
set :bundle_without, 'deploy test'
set :deploy_to, '/opt/app/pres/preservation_catalog'
set :whenever_roles, [:queue_populator, :cache_cleaner]

set :east_bucket_name, 'sul-sdr-aws-us-east-1-archive'
set :west_bucket_name, 'sul-sdr-aws-us-west-2-archive'
