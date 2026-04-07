# frozen_string_literal: true

desc 'Delete ZippedMoabVersions and ZipParts in batches, delete associated ZipEndpoint on last batch'
# For decommissioning a cloud storage endpoint (without having to remove everything all at once).
# Ops will purge the contents of the S3 bucket; or, can provide a time-limited access key and secret access key for
# the endpoint, in which case it would also be necessary to obtain or generate a list of S3 keys (druid tree paths) for
# which to delete S3 content.
task :decommission_endpoint_in_db, [:endpoint_name, :dry_run, :batch_size, :limit] => :environment do |task, args|
  logger = ActiveSupport::BroadcastLogger.new(
    Logger.new(Rails.root.join('log', 'zip_endpoint_decommission.log')),
    Logger.new($stdout)
  )

  args.with_defaults(dry_run: 'true', batch_size: 50_000, limit: 50_000)
  endpoint_name = args[:endpoint_name]
  dry_run = args[:dry_run] != 'false'
  limit = args[:limit].to_i
  batch_size = args[:batch_size].to_i

  logger.info "===== #{task.name}: interpreted args: #{{ endpoint_name:, dry_run:, batch_size:, limit: }}"
  zip_endpoint = ZipEndpoint.find_by(endpoint_name:)
  unless zip_endpoint
    logger.error 'Could not find ZipEndpoint'
    exit 1
  end

  unless dry_run
    puts 'Are you sure you want to proceed? (y/n)'
    answer = $stdin.gets.chomp.downcase
    unless answer == 'y'
      logger.info 'Quitting.'
      exit
    end
  end

  # this should be stable from run to run, as #in_batches orders on primary key
  # `use_ranges: true` prevents a giant IN clause of individual IDs: https://apidock.com/rails/ActiveRecord/Batches/in_batches
  zip_endpoint.zipped_moab_versions.limit(limit).in_batches(of: batch_size, use_ranges: true) do |zipped_moab_versions_relation|
    zip_parts_relation = ZipPart.where(zipped_moab_version: zipped_moab_versions_relation)
    zip_info = "#{zip_parts_relation.count} zip parts for #{zipped_moab_versions_relation.count} zipped moab versions " \
               "(zipped_moab_versions id range: #{zipped_moab_versions_relation.pluck('MIN(id)')} to " \
               "#{zipped_moab_versions_relation.pluck('MAX(id)')})"

    logger.debug "zipped_moab_versions_relation.to_sql=#{zipped_moab_versions_relation.to_sql}"
    logger.debug "zip_parts_relation.to_sql=#{zip_parts_relation.to_sql}"
    if dry_run
      logger.info "[Dry run] Deleting: #{zip_info}"
    else
      logger.info "Deleting: #{zip_info}"
      # delete_all issues a single SQL delete without instantiating AR objects: https://apidock.com/rails/ActiveRecord/Relation/delete_all
      zip_parts_relation.delete_all
      zipped_moab_versions_relation.delete_all
    end
  end

  # if it's not a dry run and all the zipped_moab_versions are gone, remove the endpoint
  unless dry_run || zip_endpoint.reload.zipped_moab_versions.exist?
    logger.info "Deleting ZipEndpoint: #{endpoint_name}"
    zip_endpoint.destroy!
  end
end
