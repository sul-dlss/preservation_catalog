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

require 'audit/moab_to_catalog.rb'
desc 'populate the catalog with the contents of the online storage roots'
task :seed_catalog, [:profile] => [:environment] do |_t, args|
  unless args[:profile] == 'profile' || args[:profile].nil?
    p "Usage: rake seed_catalog || rake seed_catalog[profile]"
    exit
  end

  puts "#{Time.now.utc.iso8601} Seeding the database from all storage roots..."
  $stdout.flush # sometimes above doesn't end up getting flushed to STDOUT till the last puts when the run finishes
  if args[:profile] == 'profile'
    puts 'When done, check log/profile_flat_seed_catalog_for_all_storage_roots[TIMESTAMP].log for profiling details'
    $stdout.flush
    MoabToCatalog.seed_catalog_for_all_storage_roots_profiled
  elsif args[:profile].nil?
    MoabToCatalog.seed_catalog_for_all_storage_roots
  end
  puts "#{Time.now.utc.iso8601} Done"
  $stdout.flush
end

desc "Delete single endpoint db data"
task :drop, [:storage_root] => [:environment] do |_t, args|
  if args[:storage_root]
    root = args[:storage_root]
    puts "You're about to erase all the data for #{root}. Are you sure you want to continue? [y/N]"
    input = STDIN.gets.chomp
    if input.casecmp("y").zero? # rubocop prefers casecmp because it is faster than '.downcase =='
      MoabToCatalog.drop_endpoint(root)
      puts "You have successfully deleted all the data from #{root}"
    else
      puts "You canceled erasing data from #{root}"
    end
  else
    puts "You need to enter a specific storage root"
  end
end

desc "Populate single endpoint db data"
task :populate, [:storage_root] => [:environment] do |_t, args|
  if args[:storage_root]
    root = args[:storage_root]
    puts "You're about to populate all the data for #{root}. Are you sure you want to continue? [y/N]"
    input = STDIN.gets.chomp
    if input.casecmp("y").zero? # rubocop prefers casecmp because it is faster than '.downcase =='
      MoabToCatalog.populate_endpoint(root)
      puts "You have successfully populated all the data for #{root}"
    else
      puts "You canceled populating data for #{root}"
    end
  else
    puts "You need to enter a specific storage root"
  end
end
