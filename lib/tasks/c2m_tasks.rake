desc "Fire off c2m version check on a single storage root"
task :c2m_check_version_on_dir, [:last_checked_b4_date, :storage_root, :profile] => [:environment] do |_t, args|
  unless args[:profile] == 'profile' || args[:profile].nil?
    p "usage: rake c2m_check_version_on_dir[last_checked_b4_date, fixture_sr1] || rake c2m_check_version_on_dir[last_checked_b4_date,fixture_sr1,profile]"
    exit 1
  end
  root = args[:storage_root].to_sym
  storage_dir = "#{HostSettings.storage_roots[root]}/#{Settings.moab.storage_trunk}"
  last_checked = args[:last_checked_b4_date].to_s
  begin
    if args[:profile] == 'profile'
      puts "When done, check log/profile_c2m_check_version_on_dir[TIMESTAMP].txt for profiling details"
      Audit::CatalogToMoab.check_version_on_dir_profiled(last_checked, storage_dir)
    elsif args[:profile].nil?
      Audit::CatalogToMoab.check_version_on_dir(last_checked, storage_dir)
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
  $stdout.flush
end
