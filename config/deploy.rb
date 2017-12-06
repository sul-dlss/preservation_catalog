set :application, "preservation_catalog"
set :repo_url, "https://github.com/sul-dlss/preservation_catalog.git"

# Default branch is :master
ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, "/opt/app/pres/preservation_catalog"

# update shared_configs before restarting app
before 'deploy:restart', 'shared_configs:update'

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
append :linked_files, "config/database.yml" # , "config/secrets.yml"

# Default value for linked_dirs is []
append :linked_dirs, "log", "config/settings" # , "tmp/pids", "tmp/cache", "tmp/sockets", "public/system"

set :honeybadger_env, fetch(:stage)

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
# set :keep_releases, 5

# update shared_configs before restarting app
before 'deploy:restart', 'shared_configs:update'
