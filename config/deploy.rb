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

# Default value for :linked_files is []
append :linked_files, 'config/database.yml'

# Default value for linked_dirs is []
append :linked_dirs, 'log', 'config/settings', 'tmp/pids', 'vendor/bundle'

set :honeybadger_env, fetch(:stage)

set :whenever_identifier, -> { "#{fetch(:application)}_#{fetch(:stage)}" }

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

set :sidekiq_systemd_role, :worker
set :sidekiq_systemd_use_hooks, true

# configure capistrano-rails to work with propshaft instead of sprockets
# (we don't have public/assets/.sprockets-manifest* or public/assets/manifest*.*)
set :assets_manifests, lambda {
  [release_path.join('public', fetch(:assets_prefix), '.manifest.json')]
}
