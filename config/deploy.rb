# frozen_string_literal: true

set :application, 'preservation_catalog'
set :repo_url, 'https://github.com/sul-dlss/preservation_catalog.git'

# Default branch is :main
ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, "/opt/app/pres/#{fetch(:application)}"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# for ubuntu to perform resque:pool:hot_swap
set :pty, true

# Default value for :linked_files is []
append :linked_files, 'config/database.yml', 'config/resque.yml', 'config/resque-pool.yml', 'tmp/resque-pool.lock'

# Default value for linked_dirs is []
append :linked_dirs, 'log', 'config/settings', 'tmp/pids'

set :honeybadger_env, fetch(:stage)

# the honeybadger gem should integrate automatically with capistrano-rvm but it
# doesn't appear to do so on our new Ubuntu boxes :shrug:
set :rvm_map_bins, fetch(:rvm_map_bins, []).push('honeybadger')

set :whenever_identifier, -> { "#{fetch(:application)}_#{fetch(:stage)}" }

set :resque_server_roles, :resque

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
# set :keep_releases, 5

# update shared_configs before db seed
before 'deploy:migrate', 'shared_configs:update'
after 'deploy:migrate', 'db_seed'

desc 'Run rake db:seed'
task :db_seed do
  on roles(:db) do
    within release_path do
      with rails_env: fetch(:rails_env) do
        execute :rake, 'db:seed'
      end
    end
  end
end

# TODO: this worked when tested against QA and stage, but for a couple of prod deployments,
# it seemed like this caused Resque web console to erroneously report zero workers even though
# listing resque related processes on the VM showed all the workers we'd expect to be running.
# see https://github.com/sul-dlss/preservation_catalog/issues/1836
# desc 'Prune dead Resque workers'
# after 'resque:pool:hot_swap', :prune_dead_workers do
#   on roles(:resque) do
#     within release_path do
#       with rails_env: fetch(:rails_env) do
#         # If a Resque process doesn't stop gracefully, it may leave stale state information in Redis. This call
#         # does some garbage collection, checking the current Redis state info against the actual environment,
#         # and removing entries from Redis for any workers that aren't actually running. See Resque::Worker#prune_dead_workers
#         execute :rails, 'runner', '"Resque.workers.map(&:prune_dead_workers)"'
#       end
#     end
#   end
# end
