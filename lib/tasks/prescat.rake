# frozen_string_literal: true

namespace :prescat do
  desc 'Migrate storage root, returning druids of all migrated moabs'
  task :migrate_storage_root, [:from, :to] => :environment do |_task, _args|
    puts 'This will move all complete_moabs to a new storage root.'
    puts 'WARNING: expects that "from" storage root is no longer being written to (no Moabs being created or modified)!'
    print 'Enter YES to continue: '
    input = $stdin.gets.chomp
    next unless input == 'YES'

    migration_service = StorageRootMigrationService.new(args[:from], args[:to])
    migration_service.migrate.each { |druid| puts druid }
  end

  namespace :reports do
    desc 'query for druids on storage root & dump to CSV (2nd arg optional)'
    task :msr_druids, [:storage_root_name, :csv_filename] => [:environment] do |_task, args|
      csv_loc = Reporter.moab_storage_root_druid_list_to_csv(storage_root_name: args[:storage_root_name], csv_filename: args[:csv_filename])
      puts "druids for #{args[:storage_root_name]} written to #{csv_loc}"
    end

    desc 'query for druids on storage root & dump to CSV (2nd arg optional)'
    task :msr_druid_detail, [:storage_root_name, :csv_filename] => [:environment] do |_task, args|
      csv_loc = Reporter.moab_storage_root_druid_details_to_csv(storage_root_name: args[:storage_root_name], csv_filename: args[:csv_filename])
      puts "druids for #{args[:storage_root_name]} written to #{csv_loc}"
    end

    desc 'query for druids on storage root & dump to CSV (2nd arg optional)'
    task :msr_audit_errors, [:storage_root_name, :csv_filename] => [:environment] do |_task, args|
      csv_loc = Reporter.moab_storage_root_audit_errors_to_csv(storage_root_name: args[:storage_root_name], csv_filename: args[:csv_filename])
      puts "druids for #{args[:storage_root_name]} written to #{csv_loc}"
    end
  end
end
