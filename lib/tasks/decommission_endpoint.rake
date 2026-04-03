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

  unless dry_run
    puts 'Are you sure you want to proceed? (y/n)'
    answer = $stdin.gets.chomp.downcase
    unless answer == 'y'
      puts 'Quitting.'
      exit
    end
  end

  zip_endpoint.zipped_moab_versions.find_each do |zipped_moab_version|
    zip_info = "#{zipped_moab_version.druid} (#{zipped_moab_version.version})"
    if dry_run
      puts "Dry run deleting: #{zip_info}"
    else
      puts "Deleting: #{zip_info}"
      zipped_moab_version.zip_parts.destroy_all
    end
  end

  unless dry_run
    puts "Deleting ZipEndpoint: #{args[:endpoint_name]}"
    zip_endpoint.reload
    zip_endpoint.zipped_moab_versions.destroy_all
    zip_endpoint.reload
    zip_endpoint.destroy!
  end
end
