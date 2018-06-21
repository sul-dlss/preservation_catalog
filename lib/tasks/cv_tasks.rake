namespace :cv do

  desc "Run CV (checksum validation) on a single storage root"
  task :one_root, [:storage_root, :profile] => [:environment] do |_t, args|
    unless args[:profile] == 'profile' || args[:profile].nil?
      p "usage: rake cv:one_root[storage_root] || rake cv:one_root[storage_root,profile]"
      exit 1
    end
    storage_root = args[:storage_root].to_sym
    if args[:profile] == 'profile'
      puts "When done, check log/profile_cv_validate_disk[TIMESTAMP] for profiling details"
      Audit::Checksum.validate_disk_profiled(storage_root)
    elsif args[:profile].nil?
      Audit::Checksum.validate_disk(storage_root)
    end
    puts "#{Time.now.utc.iso8601} Checksum Validation on #{storage_root} is done."
  end

  desc "Run CV (checksum validation) on all storage roots"
  task :all_roots, [:profile] => [:environment] do |_t, args|
    unless args[:profile] == 'profile' || args[:profile].nil?
      p "usage: rake cv:all_roots || rake cv:all_roots[profile]"
      exit 1
    end
    if args[:profile] == 'profile'
      puts "When done, check log/profile_cv_validate_disk_all_endpoints[TIMESTAMP].txt for profiling details"
      Audit::Checksum.validate_disk_all_endpoints_profiled
    elsif args[:profile].nil?
      Audit::Checksum.validate_disk_all_endpoints
    end
    puts "#{Time.now.utc.iso8601} Checksum Validation on all storage roots is done."
  end

  desc "Run CV (checksum validation) on a single druid"
  task :druid, [:druid] => [:environment] do |_t, args|
    druid = args[:druid].to_sym
    cv_results_lists = Audit::Checksum.validate_druid(druid)
    cv_results_lists.each do |aud_res|
      puts aud_res.to_json unless aud_res.contains_result_code?(AuditResults::MOAB_CHECKSUM_VALID)
    end

    puts "#{Time.now.utc.iso8601} Checksum Validation on #{druid} is done."
    # exit with non-zero status if any of the pres copies failed checksum validation
    exit 1 if cv_results_lists.detect { |aud_res| !aud_res.contains_result_code?(AuditResults::MOAB_CHECKSUM_VALID) }
  end

  desc "Run CV (checksum validation) on a list of druids"
  task :druid_list, [:file_path] => [:environment] do |_t, args|
    druid_list_file_path = args[:file_path]
    puts "#{Time.now.utc.iso8601} Checksum Validation on the list of druids from #{druid_list_file_path} has started"
    Audit::Checksum.validate_list_of_druids(druid_list_file_path)
    puts "#{Time.now.utc.iso8601} Checksum Validation on the list of druids from #{druid_list_file_path} is done."
  end
end
