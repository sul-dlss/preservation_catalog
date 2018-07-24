server 'preservation-catalog-prod-01.stanford.edu', user: 'pres', roles: %w[m2c c2m app db web]
server 'preservation-catalog-prod-02.stanford.edu', user: 'pres', roles: %w[cv app]
server 'preservation-catalog-prod-03.stanford.edu', user: 'pres', roles: %w[worker app resque]

Capistrano::OneTimeKey.generate_one_time_key!
set :rails_env, 'production'
set :bundle_without, 'deploy test'
set :deploy_to, '/opt/app/pres/preservation_catalog'
set :whenever_roles, [:m2c, :c2m, :cv]

set :east_bucket_name, 'sul-sdr-aws-us-east-1-archive'
set :west_bucket_name, 'sul-sdr-aws-us-west-2-archive'
