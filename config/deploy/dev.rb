server 'sul-pcc-dev.stanford.edu', user: 'pres', roles: %w[app db web]

Capistrano::OneTimeKey.generate_one_time_key!
set :rails_env, 'development'
set :bundle_without, 'deploy test'
