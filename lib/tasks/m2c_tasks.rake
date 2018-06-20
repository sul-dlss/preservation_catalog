namespace :m2c do

  desc "Populate all storage roots' db data (does more validation than regular M2C)"
  task :seed_all_roots, [:profile] => [:environment] do |_t, args|
    unless args[:profile] == 'profile' || args[:profile].nil?
      p "Usage: rake m2c:seed_all_roots || rake m2c:seed_all_roots[profile]"
      exit 1
    end

    puts "#{Time.now.utc.iso8601} Seeding the database from all storage roots..."
    $stdout.flush # sometimes above is not visible (flushed) until last puts (when run finishes)
    if args[:profile] == 'profile'
      puts 'When done, check log/profile_seed_catalog_for_all_storage_roots[TIMESTAMP].txt for profiling details'
      $stdout.flush
      Audit::MoabToCatalog.seed_catalog_for_all_storage_roots_profiled
    elsif args[:profile].nil?
      Audit::MoabToCatalog.seed_catalog_for_all_storage_roots
    end
    puts "#{Time.now.utc.iso8601} Seeding the catalog for all storage roots is done"
    $stdout.flush
  end

  desc "Delete a single storage root's db data"
  task :drop_root, [:storage_root] => [:environment] do |_t, args|
    if args[:storage_root]
      root = args[:storage_root]
      puts "You're about to erase all the data for #{root}. Are you sure you want to continue? [y/N]"
      input = STDIN.gets.chomp
      if input.casecmp("y").zero? # rubocop prefers casecmp because it is faster than '.downcase =='
        puts "Starting to drop the db for #{root}"
        Audit::MoabToCatalog.drop_endpoint(root)
        puts "You have successfully deleted all the data from #{root}"
      else
        puts "You canceled erasing data from #{root}"
      end
    else
      puts "You need to enter a specific storage root"
    end
  end

  desc "Populate a single storage root's db data (does more validation than regular M2C)"
  task :seed_root, [:storage_root, :profile] => [:environment] do |_t, args|
    unless args[:profile] == 'profile' || args[:profile].nil?
      p "Usage: rake m2c:seed_root[fixture_sr1] || rake m2c:seed_root[fixture_sr1,profile]"
      exit 1
    end
    root = args[:storage_root]
    if args[:storage_root] != 'profile'
      puts "You're about to populate all the data for #{root}. Are you sure you want to continue? [y/N]"
      input = STDIN.gets.chomp
      if input.casecmp("y").zero? # rubocop prefers casecmp because it is faster than '.downcase =='
        puts " #{Time.now.utc.iso8601} Starting to populate db for #{root}"
        if args[:profile]
          puts "When done, check log/profile_populate_endpoint.txt for profiling details"
          Audit::MoabToCatalog.populate_endpoint_profiled(root)
        else
          Audit::MoabToCatalog.populate_endpoint(root)
        end
        puts "#{Time.now.utc.iso8601} You have successfully populated all the data for #{root}"
      else
        puts "You canceled populating data for #{root}"
      end
    else
      puts "You need to enter a specific storage root"
    end
  end

  desc "Run M2C existence/version check on a single druid"
  task :druid, [:druid] => [:environment] do |_t, args|
    puts "#{Time.now.utc.iso8601} Running Moab to Catalog Existence Check for #{args[:druid]}"
    $stdout.flush # sometimes above is not visible (flushed) until last puts (when run finishes)
    Audit::MoabToCatalog.check_existence_for_druid(args[:druid])
    puts "#{Time.now.utc.iso8601} Moab to Catalog Existence Check for #{args[:druid]} is done"
    $stdout.flush
  end

  desc "Run M2C existence/version checks on a list of druids"
  task :druid_list, [:file_path] => [:environment] do |_t, args|
    druid_list_file_path = args[:file_path]
    puts "#{Time.now.utc.iso8601} Moab to Catalog Existence Check on the list of druids from #{druid_list_file_path} has started"
    Audit::MoabToCatalog.check_existence_for_druid_list(druid_list_file_path)
    puts "#{Time.now.utc.iso8601} Moab to Catalog Existence Check on the list of druids from #{druid_list_file_path} has finished"
    $stdout.flush
  end

  desc "Run M2C existence/version checks on a single storage root"
  task :one_root, [:storage_root, :profile] => [:environment] do |_t, args|
    unless args[:profile] == 'profile' || args[:profile].nil?
      p "Usage: rake m2c:one_root[fixture_sr1] || rake m2c:one_root[fixture_sr1,profile]"
      exit 1
    end
    root = args[:storage_root].to_sym
    storage_dir = "#{HostSettings.storage_roots[root]}/#{Settings.moab.storage_trunk}"
    puts "#{Time.now.utc.iso8601} Running Moab to Catalog Existence Check for #{storage_dir}"
    $stdout.flush # sometimes above is not visible (flushed) until last puts (when run finishes)
    if args[:profile] == 'profile'
      puts "When done, check log/profile_check_existence_for_dir[TIMESTAMP].txt for profiling details"
      $stdout.flush
      Audit::MoabToCatalog.check_existence_for_dir_profiled(storage_dir)
    elsif args[:profile].nil?
      Audit::MoabToCatalog.check_existence_for_dir(storage_dir)
    end
    puts "#{Time.now.utc.iso8601} Moab to Catalog Existence Check for #{storage_dir} is done"
    $stdout.flush
  end

  desc "Run M2C existence/version checks on all storage roots"
  task :all_roots, [:profile] => [:environment] do |_t, args|
    unless args[:profile] == 'profile' || args[:profile].nil?
      p "Usage: rake m2c:all_roots || rake m2c:all_roots[profile]"
      exit 1
    end

    if args[:profile] == 'profile'
      puts "When done, check log/profile_check_existence_for_all_storage_roots[TIMESTAMP].txt for profiling details"
      Audit::MoabToCatalog.check_existence_for_all_storage_roots_profiled
    elsif args[:profile].nil?
      Audit::MoabToCatalog.check_existence_for_all_storage_roots
    end
    puts "#{Time.now.utc.iso8601} Moab to Catalog Existence Check for all storage roots are done"
    $stdout.flush
  end
end
