desc "Fire off checksum validation on a single storage root"
task :cv_single_endpoint, [:storage_root, :profile] => [:environment] do |_t, args|
  unless args[:profile] == 'profile' || args[:profile].nil?
    p "usage: rake cv_single_endpoint[storage_root] || rake cv_single_endpoint[storage_root,profile]"
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
  $stdout.flush
end

desc "Fire off checksum validation on all storage roots"
task :cv_all_endpoints, [:profile] => [:environment] do |_t, args|
  unless args[:profile] == 'profile' || args[:profile].nil?
    p "usage: rake cv_all_endpoints || rake cv_all_endpoints[profile]"
    exit 1
  end
  if args[:profile] == 'profile'
    puts "When done, check log/profile_cv_validate_disk_all_endpoints[TIMESTAMP].txt for profiling details"
    Audit::Checksum.validate_disk_all_endpoints_profiled
  elsif args[:profile].nil?
    Audit::Checksum.validate_disk_all_endpoints
  end
  puts "#{Time.now.utc.iso8601} Checksum Validation on all storage roots are done."
  $stdout.flush
end

desc "Fire off checksum validation via druid"
task :cv_druid, [:druid] => [:environment] do |_t, args|
  druid = args[:druid].to_sym

  cv_results_lists = Audit::Checksum.validate_druid(druid)
  cv_results_lists.each do |aud_res|
    puts aud_res.to_json unless aud_res.contains_result_code?(AuditResults::MOAB_CHECKSUM_VALID)
  end

  puts "#{Time.now.utc.iso8601} Checksum Validation on #{druid} is done."
  $stdout.flush

  # exit with non-zero status if any of the pres copies failed checksum validation
  exit 1 if cv_results_lists.detect { |aud_res| !aud_res.contains_result_code?(AuditResults::MOAB_CHECKSUM_VALID) }
end

desc "Fire off checksum validation on a list of druids"
task :cv_druid_list, [:file_path] => [:environment] do |_t, args|
  druid_list_file_path = args[:file_path]
  puts "#{Time.now.utc.iso8601} Checksum Validation on the list of druids from #{druid_list_file_path} has started"
  Audit::Checksum.validate_list_of_druids(druid_list_file_path)
  puts "#{Time.now.utc.iso8601} Checksum Validation on the list of druids from #{druid_list_file_path} has finished."
  $stdout.flush
end
