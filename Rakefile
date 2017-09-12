# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative 'config/application'

Rails.application.load_tasks

require 'rubocop/rake_task'
RuboCop::RakeTask.new

task default: [:spec, :rubocop]

task :init_postgres, [:username] do |_task, args|
  user_argument = "-U " + args[:username] unless args[:username].nil?
  sh("psql -c 'CREATE USER preservation_core_catalog;' #{user_argument}")
  sh("psql -c 'ALTER USER preservation_core_catalog CREATEDB;' #{user_argument}")
  sh("psql -c 'CREATE DATABASE preservation_core_catalog;' #{user_argument}")
  sh("psql -c 'ALTER DATABASE preservation_core_catalog OWNER TO preservation_core_catalog;' #{user_argument}")
  sh("psql -c 'GRANT ALL PRIVILEGES ON DATABASE preservation_core_catalog TO preservation_core_catalog;' \
      #{user_argument}")
end
