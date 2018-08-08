namespace :m2c do
  desc "Delete a single storage root's db data"
  task :drop_root, [:storage_root] => [:environment] do |_t, args|
    if args[:storage_root]
      root = args[:storage_root]
      puts "You're about to erase all the data for #{root}. Are you sure you want to continue? [y/N]"
      input = STDIN.gets.chomp
      if input.casecmp("y").zero? # rubocop prefers casecmp because it is faster than '.downcase =='
        puts "Starting to drop the db for #{root}"
        Audit::MoabToCatalog.drop_moab_storage_root(root)
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
          puts "When done, check log/profile_populate_moab_storage_root.txt for profiling details"
          Audit::MoabToCatalog.populate_moab_storage_root_profiled(root)
        else
          Audit::MoabToCatalog.populate_moab_storage_root(root)
        end
        puts "#{Time.now.utc.iso8601} You have successfully populated all the data for #{root}"
      else
        puts "You canceled populating data for #{root}"
      end
    else
      puts "You need to enter a specific storage root"
    end
  end
end
