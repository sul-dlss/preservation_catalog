namespace :c2m do

  desc "Run C2M version checks on a single storage root"
  task :one_root, [:last_checked_b4_date, :storage_root, :profile] => [:environment] do |_t, args|
    unless args[:profile] == 'profile' || args[:profile].nil?
      p "usage: rake c2m:one_root[last_checked_b4_date, fixture_sr1] || rake c2m:one_root[last_checked_b4_date,fixture_sr1,profile]"
      exit 1
    end
    root = args[:storage_root].to_sym
    storage_dir = "#{HostSettings.storage_roots[root]}/#{Settings.moab.storage_trunk}"
    last_checked = args[:last_checked_b4_date].to_s
    begin
      if args[:profile] == 'profile'
        puts "When done, check log/profile_C2M_check_version_on_dir[TIMESTAMP].txt for profiling details"
        Audit::CatalogToMoab.check_version_on_dir_profiled(last_checked, storage_dir)
      elsif args[:profile].nil?
        Audit::CatalogToMoab.check_version_on_dir(last_checked, storage_dir)
      end
      puts "#{Time.now.utc.iso8601} Catalog to Moab version check on #{storage_dir} is done."
    rescue TypeError, ArgumentError
      p "You've entered an incorrect timestamp format #{last_checked}."
      p "Please enter correct timestamp format (UTC) (2018-02-01T18:54:48Z)"
    end
  end

  desc "Run C2M version checks on all storage roots"
  task :all_roots, [:last_checked_b4_date, :profile] => [:environment] do |_t, args|
    unless args[:profile] == 'profile' || args[:profile].nil?
      p "usage: rake c2m:all_roots[last_checked_b4_date] || rake c2m:all_roots[last_checked_b4_date,profile]"
      exit 1
    end
    last_checked = args[:last_checked_b4_date].to_s
    begin
      if args[:profile] == 'profile'
        puts "When done, check log/profile_C2M_check_version_all_roots[TIMESTAMP].txt for profiling details"
        Audit::CatalogToMoab.check_version_all_dirs_profiled(last_checked)
      elsif args[:profile].nil?
        Audit::CatalogToMoab.check_version_all_dirs(last_checked)
      end
      puts "#{Time.now.utc.iso8601} Catalog to Moab version check on all roots is done."
    rescue TypeError, ArgumentError
      p "You've entered an incorrect timestamp format #{last_checked}."
      p "Please enter correct timestamp format (UTC) (2018-02-01T18:54:48Z)"
    end
  end
end
