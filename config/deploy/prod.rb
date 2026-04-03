# frozen_string_literal: true

server 'preservation-catalog-web-prod-01.stanford.edu', user: 'pres', roles: %w[app web]
server 'preservation-catalog-web-prod-02.stanford.edu', user: 'pres', roles: %w[app web]
server 'preservation-catalog-worker-prod-01.stanford.edu', user: 'pres', roles: %w[app db worker scheduler]
server 'preservation-catalog-worker-prod-02.stanford.edu', user: 'pres', roles: %w[app worker]
server 'preservation-catalog-worker-prod-03.stanford.edu', user: 'pres', roles: %w[app worker]

set :rails_env, 'production'
set :bundle_without, 'deploy test'
set :deploy_to, '/opt/app/pres/preservation_catalog'
