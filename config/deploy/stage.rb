# frozen_string_literal: true

server 'preservation-catalog-web-stage-01.stanford.edu', user: 'pres', roles: %w[app web]
server 'preservation-catalog-web-stage-02.stanford.edu', user: 'pres', roles: %w[app web]
server 'preservation-catalog-worker-stage-01.stanford.edu', user: 'pres', roles: %w[app db worker scheduler]

set :rails_env, 'production'
set :bundle_without, 'deploy test'
set :deploy_to, '/opt/app/pres/preservation_catalog'
