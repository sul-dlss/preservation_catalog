# frozen_string_literal: true

namespace :prescat do
  desc 'Diagnose failed replication'
  task :diagnose_replication, [:druid] => :environment do |_task, args|
    debug_infos = Audit::ReplicationSupport.zip_part_debug_info(args[:druid])
    CSV do |csv|
      csv << ['druid', 'preserved object version', 'zipped moab version', 'endpoint',
              'zip part status', 'zip part suffix', 'zipped moab parts count', 'zip part size',
              'zip part md5', 'zip part id',
              'zip part created at', 'zip part updated at', 'zip part s3 key', 'zip part endpoint status',
              'zip part endpoint md5']
      debug_infos.each { |debug_info| csv << debug_info }
    end
  end

  desc 'Prune failed replication records from catalog'
  task :prune_failed_replication, [:druid, :version, :verify_expiration] => :environment do |_task, args|
    args.with_defaults(verify_expiration: 'true')
    Replication::FailureRemediator.prune_replication_failures(
      druid: args[:druid],
      version: args[:version],
      verify_expiration: args[:verify_expiration] == 'true'
    ).each do |zmv_version, endpoint_name|
      puts "pruned zipped moab version #{zmv_version} on #{endpoint_name}"
    end
  end

  desc 'Determine if temporary local zip is present'
  task :check_temp_zip, [:druid, :version] => :environment do |_task, args|
    file_path = Replication::DruidVersionZip.new(args[:druid], args[:version]).file_path
    puts "#{file_path} exists: #{File.exist?(file_path)}"
  end

  desc 'Backfill zipped moab versions'
  task :backfill, [:druid] => :environment do |_task, args|
    zipped_moab_versions = PreservedObject.find_by(druid: args[:druid]).create_zipped_moab_versions!
    puts "Backfilled with: #{zipped_moab_versions}"
  end

  desc 'Purge zips from cloud storage'
  # For purging zips from cloud storage one endpoint at a time.
  # Ops will provide a time-limited access key and secret access key for the endpoint.
  # CSV should be in the format of druid,version,endpoint_name without a header.
  # For example: druid:bd632bd2980,3,aws_s3_east_1
  task :purge_zips, [:csv_filename, :endpoint_name, :access_key, :secret_access_key, :dry_run] => :environment do |_task, args|
    args.with_defaults(dry_run: 'true')

    provider = case args[:endpoint_name]
               when 'aws_s3_east_1'
                 Replication::AwsProvider.new(region: Settings.zip_endpoints.aws_s3_east_1.region,
                                              access_key_id: args[:access_key],
                                              secret_access_key: args[:secret_access_key])
               when 'aws_s3_west_2'
                 Replication::AwsProvider.new(region: Settings.zip_endpoints.aws_s3_west_2.region,
                                              access_key_id: args[:access_key],
                                              secret_access_key: args[:secret_access_key])
               when 'ibm_us_south'
                 Replication::IbmProvider.new(region: Settings.zip_endpoints.ibm_us_south.region,
                                              access_key_id: args[:access_key],
                                              secret_access_key: args[:secret_access_key])
               else
                 raise ArgumentError, "Unknown endpoint_name: #{args[:endpoint_name]}"
               end
    zip_endpoint = ZipEndpoint.find_by(endpoint_name: args[:endpoint_name])

    CSV.foreach(args[:csv_filename], headers: [:druid, :version, :endpoint_name]) do |row|
      next unless row[:endpoint_name] == args[:endpoint_name]

      druid = row[:druid].delete_prefix('druid:')
      version = row[:version].to_i
      zipped_moab_version = ZippedMoabVersion.by_druid(druid).find_by(zip_endpoint: zip_endpoint, version: version)
      next unless zipped_moab_version

      zipped_moab_version.zip_parts.each do |zip_part|
        zip_info = "#{druid} (#{version}) #{zip_part.s3_key} from #{args[:endpoint_name]}"
        s3_object = provider.bucket.object(zip_part.s3_key)
        unless s3_object.exists?
          puts "Skipping since does not exist: #{zip_info}"
          next
        end
        if args[:dry_run] == 'false'
          puts "Deleting: #{zip_info}"
          s3_object.delete
          zip_part.not_found!
        else
          puts "Dry run deleting: #{zip_info}"
        end
      end
    end
  end

  namespace :cache_cleaner do
    desc 'Clean zip storage cache of empty directories'
    task empty_directories: :environment do
      # Setting mindepth to 1 prevents the command from wiping out the root dir if empty
      `find #{Settings.zip_storage} -mindepth 1 -not -path "*/\.*" -type d -empty -delete`
    end

    desc 'Clean zip storage cache of stale checksum & zip files'
    task stale_files: :environment do
      `find #{Settings.zip_storage} -mindepth 3 -type f -amin #{Settings.zip_cache_expiry_time} -delete`
    end
  end

  desc 'Migrate storage root, returning druids of all migrated moabs'
  task :migrate_storage_root, [:from, :to] => :environment do |_task, args|
    puts 'This will move all moab_records from the old storage root to a new storage root.'
    puts 'WARNING: expects that "from" storage root is no longer being written to (no Moabs being created or modified)!'
    print 'Enter YES to continue: '
    input = $stdin.gets.chomp
    next unless input == 'YES'

    migration_service = StorageRootMigrationService.new(args[:from], args[:to])
    timestamp_str = DateTime.now.utc.iso8601.gsub(':', '') # colons are a pain to deal with on CLI, so just remove them
    filename = Rails.root.join('log', "migrate_moabs_from_#{args[:from]}_to_#{args[:to]}_#{timestamp_str}.csv")
    count = 0
    CSV.open(filename, 'w') do |csv|
      csv << ['druid']
      migration_service.migrate.each do |druid|
        csv << [druid]
        count += 1
      end
    end
    puts "migrated #{count} MoabRecord records from #{args[:from]} to #{args[:to]}, druid list available at #{filename}"
  end

  namespace :reports do
    desc 'query for druids on storage root & dump to CSV (2nd & 3rd arg optional)'
    task :msr_druids, [:storage_root_name, :report_tag, :csv_filename] => [:environment] do |_task, args|
      reporter = MoabStorageRootReportService.new(storage_root_name: args[:storage_root_name])
      csv_loc = reporter.write_to_csv(reporter.druid_csv_list, report_type: 'druids', report_tag: args[:report_tag], filename: args[:csv_filename])
      puts "druids for #{args[:storage_root_name]} written to #{csv_loc}"
    end

    desc 'query for druids on storage root & dump details to CSV (2nd & 3rd arg optional)'
    task :msr_moab_status_details, [:storage_root_name, :report_tag, :csv_filename] => [:environment] do |_task, args|
      reporter = MoabStorageRootReportService.new(storage_root_name: args[:storage_root_name])
      data = reporter.moab_detail_csv_list
      csv_loc = reporter.write_to_csv(data, report_type: 'moab_status_details', report_tag: args[:report_tag], filename: args[:csv_filename])
      puts "druid details for #{args[:storage_root_name]} written to #{csv_loc}"
    end

    desc 'query for druids on storage root & dump audit error details to CSV (2nd & 3rd arg optional)'
    task :msr_moab_audit_errors, [:storage_root_name, :report_tag, :csv_filename] => [:environment] do |_task, args|
      reporter = MoabStorageRootReportService.new(storage_root_name: args[:storage_root_name])
      data = reporter.moab_detail_csv_list(errors_only: true)
      csv_loc = reporter.write_to_csv(data, report_type: 'moab_audit_errors', report_tag: args[:report_tag], filename: args[:csv_filename])
      puts "druids with errors details for #{args[:storage_root_name]} written to #{csv_loc}"
    end
  end

  namespace :audit do
    desc 'run M2C (moab to catalog) validation on a storage root'
    task :m2c, [:storage_root_name] => [:environment] do |_task, args|
      msr = MoabStorageRoot.find_by!(name: args[:storage_root_name])
      msr.m2c_check!
    end

    desc 'run C2M (catalog to moab) validation on a storage root'
    task :c2m, [:storage_root_name] => [:environment] do |_task, args|
      msr = MoabStorageRoot.find_by!(name: args[:storage_root_name])
      msr.c2m_check!
    end

    desc 'run CV (checksum validation) for all druids on a storage root'
    task :cv, [:storage_root_name] => [:environment] do |_task, args|
      MoabStorageRoot.find_by!(name: args[:storage_root_name]).moab_records.find_each(&:validate_checksums!)
    end

    desc 'run CV (checksum validation) for a single druid'
    task :cv_single, [:druid] => [:environment] do |_task, args|
      puts "Starting checksum validation for #{args[:druid]}"
      MoabRecord.by_druid(args[:druid]).first.validate_checksums!
      puts 'This may take some time. Any issues will be reported to Honeybadger.'
    end

    desc 'validate checksums in a Moab directory outside of a known storage root (i.e., not in the catalog)'
    task :validate_uncataloged, [:druid, :storage_location] => [:environment] do |_task, args|
      puts "Starting checksum validation for #{args[:druid]} in #{args[:storage_location]} (NOTE: this may take some time!)"
      Audit::ChecksumValidator.new(
        moab_storage_object: MoabOnStorage.moab(storage_location: args[:storage_location], druid: args[:druid]),
        emit_results: true
      ).validate!
    end

    desc 'run replication audit for a single druid'
    task :replication_single, [:druid] => [:environment] do |_task, args|
      puts "Starting replication audit for #{args[:druid]}"
      PreservedObject.find_by!(druid: args[:druid]).audit_moab_version_replication!
      puts 'This may take some time. Any issues will be reported to Honeybadger.'
    end
  end
end
