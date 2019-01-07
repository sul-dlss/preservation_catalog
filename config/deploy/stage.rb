server 'preservation-catalog-stage-01.stanford.edu', user: 'pres', roles: %w[app db web]
server 'preservation-catalog-stage-02.stanford.edu', user: 'pres', roles: %w[resque app]

Capistrano::OneTimeKey.generate_one_time_key!
set :rails_env, 'production'
set :bundle_without, 'deploy test'
set :deploy_to, '/opt/app/pres/preservation_catalog'
append :linked_files, "config/newrelic.yml", "config/resque.yml"

set :east_bucket_name, 'sul-sdr-aws-us-east-1-test'
set :west_bucket_name, 'sul-sdr-aws-us-west-2-test'
set :south_bucket_name, 'sul-sdr-ibm-us-south-1-ia'
