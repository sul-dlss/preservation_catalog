# frozen_string_literal: true

server 'preservation-catalog-web-prod-01.stanford.edu', user: 'pres', roles: %w[app web]
server 'preservation-catalog-web-prod-02.stanford.edu', user: 'pres', roles: %w[app web]
server 'preservation-catalog-prod-02.stanford.edu', user: 'pres', roles: %w[app db resque queue_populator]
server 'preservation-catalog-prod-03.stanford.edu', user: 'pres', roles: %w[app resque]
server 'preservation-catalog-prod-04.stanford.edu', user: 'pres', roles: %w[app resque cache_cleaner]

# for ubuntu to perform resque:pool:hot_swap
set :pty, true

Capistrano::OneTimeKey.generate_one_time_key!
set :rails_env, 'production'
set :bundle_without, 'deploy test'
set :deploy_to, '/opt/app/pres/preservation_catalog'
set :whenever_roles, [:queue_populator, :cache_cleaner]
