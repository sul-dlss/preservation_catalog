server 'preservation-catalog-stage.stanford.edu', user: 'pres', roles: %w[app db web]
server 'preservation-worker-stage.stanford.edu', user: 'pres', roles: %w[app db web]

Capistrano::OneTimeKey.generate_one_time_key!
set :rails_env, 'production'
set :bundle_without, 'deploy test'
set :deploy_to, '/opt/app/pres/preservation_catalog'

# uncomment if/when we turn newrelic on
# append :linked_files, "config/newrelic.yml"
