# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative 'config/application'

Rails.application.load_tasks

require 'rubocop/rake_task'
RuboCop::RakeTask.new

task default: [:spec, :rubocop]

task :travis_setup_postgres do
  sh("psql -U postgres -f db/scripts/pres_test_setup.sql")
end

require_relative 'lib/audit/moab_to_catalog'
task seed_catalog: :environment do
  m2c = MoabToCatalog.new
  puts "Seeding the database from all storage roots..."
  m2c.seed_from_disk
  puts "Done"
end
