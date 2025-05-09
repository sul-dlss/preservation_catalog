# frozen_string_literal: true

server 'preservation-catalog-web-stage-01.stanford.edu', user: 'pres', roles: %w[app web]
server 'preservation-catalog-web-stage-02.stanford.edu', user: 'pres', roles: %w[app web]
server 'preservation-catalog-stage-02.stanford.edu', user: 'pres', roles: %w[app db worker queue_populator cache_cleaner]

set :rails_env, 'production'
set :bundle_without, 'deploy test'
set :deploy_to, '/opt/app/pres/preservation_catalog'
set :whenever_roles, [:queue_populator, :cache_cleaner]
