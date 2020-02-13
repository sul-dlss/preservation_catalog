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
      reporter = MoabStorageRootReporter.new(storage_root_name: args[:storage_root_name])
      csv_loc = reporter.write_to_csv(reporter.druid_csv_list, report_type: 'druids', filename: args[:csv_filename])
      puts "druids for #{args[:storage_root_name]} written to #{csv_loc}"
    end

    desc 'query for druids on storage root & dump details to CSV (2nd arg optional)'
    task :msr_moab_status_details, [:storage_root_name, :csv_filename] => [:environment] do |_task, args|
      reporter = MoabStorageRootReporter.new(storage_root_name: args[:storage_root_name])
      data = reporter.moab_detail_csv_list
      csv_loc = reporter.write_to_csv(data, report_type: 'moab_status_details', filename: args[:csv_filename])
      puts "druid details for #{args[:storage_root_name]} written to #{csv_loc}"
    end

    desc 'query for druids on storage root & dump audit error details to CSV (2nd arg optional)'
    task :msr_moab_audit_errors, [:storage_root_name, :csv_filename] => [:environment] do |_task, args|
      reporter = MoabStorageRootReporter.new(storage_root_name: args[:storage_root_name])
      data = reporter.moab_detail_csv_list(errors_only: true)
      csv_loc = reporter.write_to_csv(data, report_type: 'moab_audit_errors', filename: args[:csv_filename])
      puts "druids with errors details for #{args[:storage_root_name]} written to #{csv_loc}"
    end
  end
end
