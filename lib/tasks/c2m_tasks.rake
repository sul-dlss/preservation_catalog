namespace :c2m do
  desc "Run C2M version checks on a single storage root"
  task :one_root, [:last_checked_b4_date, :storage_root] => [:environment] do |_t, args|
    root_key = args[:storage_root].to_sym
    last_checked = args[:last_checked_b4_date].to_s
    storage_dir = "#{HostSettings.storage_roots[root_key]}/#{Settings.moab.storage_trunk}"
    root = MoabStorageRoot.find_by!(storage_location: storage_dir)
    begin
      root.c2m_check!(last_checked_b4_date)
    rescue TypeError, ArgumentError
      p "You've entered an incorrect timestamp format #{last_checked}."
      p "Please enter correct timestamp format (UTC) (2018-02-01T18:54:48Z)"
    end
  end

  desc "Run C2M version checks on all storage roots"
  task :all_roots, [:last_checked_b4_date] => [:environment] do |_t, args|
    last_checked = args[:last_checked_b4_date].to_s
    begin
      MoabStorageRoot.find_each { |root| root.c2m_check!(last_checked) }
    rescue TypeError, ArgumentError
      p "You've entered an incorrect timestamp format #{last_checked}."
      p "Please enter correct timestamp format (UTC) (2018-02-01T18:54:48Z)"
    end
  end
end
