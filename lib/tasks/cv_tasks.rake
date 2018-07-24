namespace :cv do

  desc "Run CV (checksum validation) on a single storage root"
  task :one_root, [:storage_root] => [:environment] do |_t, args|
    if args[:storage_root].nil?
      p "usage: rake cv:one_root[storage_root]"
      exit 1
    end
    Audit::Checksum.validate_disk(args[:storage_root].to_sym)
    puts "#{Time.now.utc.iso8601} Checksum Validation on #{storage_root} is done."
  end

  desc "Run CV (checksum validation) on all storage roots"
  task all_roots: [:environment] do
    Audit::Checksum.validate_disk_all_storage_roots
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
