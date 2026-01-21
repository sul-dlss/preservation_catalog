# frozen_string_literal: true

desc 'Purge zips from cloud storage for decommissioned ZipEndpoint and remove ZippedMoabVersions and ZipParts'
# For decommissioning a cloud storage endpoint
# Ops will provide a time-limited access key and secret access key for the endpoint.
task :decommission_endpoint, [:endpoint_name, :access_key, :secret_access_key, :dry_run] => :environment do |_task, args|
  args.with_defaults(dry_run: 'true')
  dry_run = args[:dry_run] != 'false'

  zip_endpoint = ZipEndpoint.find_by(endpoint_name: args[:endpoint_name])
  unless zip_endpoint
    puts 'Could not find ZipEndpoint'
    exit 1
  end
  provider = Replication::ProviderFactory.create(zip_endpoint:, access_key_id: args[:access_key], secret_access_key: args[:secret_access_key])

  unless dry_run
    puts 'Are you sure you want to proceed? (y/n)'
    answer = $stdin.gets.chomp.downcase
    unless answer == 'y'
      puts 'Quitting.'
      exit
    end
  end

  zip_endpoint.zipped_moab_versions.find_each do |zipped_moab_version|
    zipped_moab_version.zip_parts.each do |zip_part|
      zip_info = "#{zipped_moab_version.druid} (#{zipped_moab_version.version}) #{zip_part.s3_key}"
      s3_object = provider.bucket.object(zip_part.s3_key)

      if dry_run
        puts "Dry run deleting: #{zip_info}"
      else
        puts "Deleting: #{zip_info}"
        s3_object.delete if s3_object.exists?
        zip_part.destroy!
      end
    end
    zipped_moab_version.destroy! unless dry_run
  end

  unless dry_run
    puts "Deleting ZipEndpoint: #{args[:endpoint_name]}"
    zip_endpoint.destroy!
  end
end
