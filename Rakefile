# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative 'config/application'
require 'audit/moab_to_catalog.rb'
require 'audit/catalog_to_moab.rb'
require 'audit/checksum.rb'

Rails.application.load_tasks

require 'rubocop/rake_task'
RuboCop::RakeTask.new

task default: [:spec, :rubocop]

task :travis_setup_postgres do
  sh("psql -U postgres -f db/scripts/pres_test_setup.sql")
end

desc 'populate the catalog with the contents of the online storage roots'
task :seed_catalog, [:profile] => [:environment] do |_t, args|
  unless args[:profile] == 'profile' || args[:profile].nil?
    p "Usage: rake seed_catalog || rake seed_catalog[profile]"
    exit
  end

  puts "#{Time.now.utc.iso8601} Seeding the database from all storage roots..."
  $stdout.flush # sometimes above is not visible (flushed) until last puts (when run finishes)
  if args[:profile] == 'profile'
    puts 'When done, check log/profile_seed_catalog_for_all_storage_roots[TIMESTAMP].txt for profiling details'
    $stdout.flush
    MoabToCatalog.seed_catalog_for_all_storage_roots_profiled
  elsif args[:profile].nil?
    MoabToCatalog.seed_catalog_for_all_storage_roots
  end
  puts "#{Time.now.utc.iso8601} Seeding the catalog for all storage roots is done"
  $stdout.flush
end

desc "Delete single endpoint db data"
task :drop, [:storage_root] => [:environment] do |_t, args|
  if args[:storage_root]
    root = args[:storage_root]
    puts "You're about to erase all the data for #{root}. Are you sure you want to continue? [y/N]"
    input = STDIN.gets.chomp
    if input.casecmp("y").zero? # rubocop prefers casecmp because it is faster than '.downcase =='
      puts "Starting to drop the db for #{root}"
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
task :populate, [:storage_root, :profile] => [:environment] do |_t, args|
  unless args[:profile] == 'profile' || args[:profile].nil?
    p "Usage: rake populate[fixture_sr1] || rake populate[fixture_sr1,profile]"
    exit
  end
  root = args[:storage_root]
  if args[:storage_root] != 'profile'
    puts "You're about to populate all the data for #{root}. Are you sure you want to continue? [y/N]"
    input = STDIN.gets.chomp
    if input.casecmp("y").zero? # rubocop prefers casecmp because it is faster than '.downcase =='
      puts " #{Time.now.utc.iso8601} Starting to populate db for #{root}"
      if args[:profile]
        puts "When done, check log/profile_populate_endpoint.txt for profiling details"
        MoabToCatalog.populate_endpoint_profiled(root)
      else
        MoabToCatalog.populate_endpoint(root)
      end
      puts "#{Time.now.utc.iso8601} You have successfully populated all the data for #{root}"
    else
      puts "You canceled populating data for #{root}"
    end
  else
    puts "You need to enter a specific storage root"
  end
end

desc "Fire off M2C existence check on a single storage root"
task :m2c_exist_single_root, [:storage_root, :profile] => [:environment] do |_t, args|
  unless args[:profile] == 'profile' || args[:profile].nil?
    p "Usage: rake m2c_exist_single_root[fixture_sr1] || rake m2c_exist_single_root[fixture_sr1,profile]"
    exit
  end
  root = args[:storage_root].to_sym
  storage_dir = "#{Settings.moab.storage_roots[root]}/#{Settings.moab.storage_trunk}"
  puts "#{Time.now.utc.iso8601} Running Moab to Catalog Existence Check for #{storage_dir}"
  $stdout.flush # sometimes above is not visible (flushed) until last puts (when run finishes)
  if args[:profile] == 'profile'
    puts "When done, check log/profile_check_existence_for_dir[TIMESTAMP].txt for profiling details"
    $stdout.flush
    MoabToCatalog.check_existence_for_dir_profiled(storage_dir)
  elsif args[:profile].nil?
    MoabToCatalog.check_existence_for_dir(storage_dir)
  end
  puts "#{Time.now.utc.iso8601} Moab to Catalog Existence Check for #{storage_dir} is done"
  $stdout.flush
end

desc "Fire off M2C existence check on all storage roots"
task :m2c_exist_all_storage_roots, [:profile] => [:environment] do |_t, args|
  unless args[:profile] == 'profile' || args[:profile].nil?
    p "Usage: rake m2c_exist_all_storage_roots || rake m2c_exist_all_storage_roots[profile]"
    exit
  end

  if args[:profile] == 'profile'
    puts "When done, check log/profile_check_existence_for_all_storage_roots[TIMESTAMP].txt for profiling details"
    MoabToCatalog.check_existence_for_all_storage_roots_profiled
  elsif args[:profile].nil?
    MoabToCatalog.check_existence_for_all_storage_roots
  end
  puts "#{Time.now.utc.iso8601} Moab to Catalog Existence Check for all storage roots are done"
  $stdout.flush
end

desc "Fire off c2m version check on a single storage root"
task :c2m_check_version_on_dir, [:last_checked_b4_date, :storage_root, :profile] => [:environment] do |_t, args|
  unless args[:profile] == 'profile' || args[:profile].nil?
    p "usage: rake c2m_check_version_on_dir[last_checked_b4_date, fixture_sr1] || rake c2m_check_version_on_dir[last_checked_b4_date,fixture_sr1,profile]"
    exit
  end
  root = args[:storage_root].to_sym
  storage_dir = "#{Settings.moab.storage_roots[root]}/#{Settings.moab.storage_trunk}"
  last_checked = args[:last_checked_b4_date].to_s
  begin
    if args[:profile] == 'profile'
      puts "When done, check log/profile_c2m_check_version_on_dir[TIMESTAMP].txt for profiling details"
      CatalogToMoab.check_version_on_dir_profiled(last_checked, storage_dir)
    elsif args[:profile].nil?
      CatalogToMoab.check_version_on_dir(last_checked, storage_dir)
    end
    puts "#{Time.now.utc.iso8601} Catalog to Moab version check on #{storage_dir} is done."
  rescue TypeError, ArgumentError
    p "You've entered an incorrect timestamp format #{last_checked}."
    p "Please enter correct timestamp format (UTC) (2018-02-01T18:54:48Z)"
  end
  $stdout.flush
end

desc "Fire off c2m version check on all storage roots"
task :c2m_check_version_all_dirs, [:last_checked_b4_date, :profile] => [:environment] do |_t, args|
  unless args[:profile] == 'profile' || args[:profile].nil?
    p "usage: rake c2m_check_version_all_dirs[last_checked_b4_date] || rake c2m_check_version_all_dirs[last_checked_b4_date,profile]"
    exit
  end
  last_checked = args[:last_checked_b4_date].to_s
  begin
    if args[:profile] == 'profile'
      puts "When done, check log/profile_C2M_check_version_all_roots[TIMESTAMP].txt for profiling details"
      CatalogToMoab.check_version_all_dirs_profiled(last_checked)
    elsif args[:profile].nil?
      CatalogToMoab.check_version_all_dirs(last_checked)
    end
    puts "#{Time.now.utc.iso8601} Catalog to Moab version check on all roots is done."
  rescue TypeError, ArgumentError
    p "You've entered an incorrect timestamp format #{last_checked}."
    p "Please enter correct timestamp format (UTC) (2018-02-01T18:54:48Z)"
  end
  $stdout.flush
end

desc "Fire off checksum validation on a single storage root"
task :cv_single_endpoint, [:storage_root, :profile] => [:environment] do |_t, args|
  unless args[:profile] == 'profile' || args[:profile].nil?
    p "usage: rake cv_single_endpoint[storage_root] || rake cv_single_endpoint[storage_root,profile]"
    exit
  end
  storage_root = args[:storage_root].to_sym
  if args[:profile] == 'profile'
    puts "When done, check log/profile_cv_single_endpoint[TIMESTAMP] for profiling details"
    Checksum.validate_disk_profiled(storage_root)
  elsif args[:profile].nil?
    Checksum.validate_disk(storage_root)
  end
  puts "#{Time.now.utc.iso8601} Checksum Validation on #{storage_root} is done."
  $stdout.flush
end

desc "Fire off checksum validation on all storage roots"
task :cv_all_endpoints, [:profile] => [:environment] do |_t, args|
  unless args[:profile] == 'profile' || args[:profile].nil?
    p "usage: rake cv_all_endpoints || rake cv_all_endpoints[profile]"
    exit
  end
  if args[:profile] == 'profile'
    puts "When done, check log/profile_cv_all_endpoints[TIMESTAMP].txt for profiling details"
    Checksum.validate_disk_all_endpoints_profiled
  elsif args[:profile].nil?
    Checksum.validate_disk_all_endpoints
  end
  puts "#{Time.now.utc.iso8601} Checksum Validation on all storage roots are done."
  $stdout.flush
end
