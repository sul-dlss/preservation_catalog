#!/usr/bin/env ruby
# frozen_string_literal: true

# This script will pull objects from the preservation cloud archives, and fixity check
# them, using the preservation_catalog Audit::ChecksumValidator class.  It will report
# any errors that are found.  The list of druids to retrieve is specified by any combo
# of druids listed in a file (one bare druid per line with no druid: prefix), random
# sampling of Moabs smaller than the zip segmenting threshold, and random sampling of
# Moabs larger than the zip segmenting threshold.
#
# WARNING: this does some naive things that assume that the druid lists won't be more than
# a few hundred long, or possibly a few thousand, since druid lists will be plucked from query
# results and held in memory, parsed naively from file and held in memory, made unique with
# Ruby Array#uniq, etc.

# Set default environment if not already set by the command line
ENV["RAILS_ENV"] ||= "production"

require_relative '../config/environment'
require 'optparse'

include ActionView::Helpers::NumberHelper

# somewhat duplicative of DruidVersionZip.ZIP_SPLIT_SIZE = '10g', but that's
# zip format, and this is just bytes as an int, which is what the query wants
ZIP_SEGMENT_THRESHOLD_GB = 10
ZIP_SEGMENT_THRESHOLD = ZIP_SEGMENT_THRESHOLD_GB.gigabytes

options = {
  druid_list: '',
  druid_list_file: nil,
  single_part_druid_sample_count: 0,
  multipart_druid_sample_count: 0,
  fixity_check_base_location: "/tmp/#{ENV['USER']}/archive_fixity_checking/",
  endpoints_to_audit: 'aws_s3_west_2,aws_s3_east_1,gcp_s3_south_1,ibm_us_south',
  force_part_md5_comparison: false,
  dry_run: false,
  quiet: false
}

parser = OptionParser.new do |option_parser|
  option_parser.banner = "Usage: #{$PROGRAM_NAME} [options]"
  option_parser.on('--druid_list DRUID_LIST',
                   'comma-separated (no spaces) list of bare druids (no prefixes)')
  option_parser.on('--druid_list_file DRUID_LIST_FILE',
                   'file with a list of provided druids, e.g. from integration tests, manual tests, your own queries, etc')
  option_parser.on('--fixity_check_base_location FIXITY_CHECK_BASE_LOCATION',
                   'target directory for downloading cloud archived Moabs, where they will be inflated and fixity checked.  ensure sufficient free space.')
  option_parser.on('--single_part_druid_sample_count SINGLE_PART_DRUID_SAMPLE_COUNT',
                   'number of < 10 GB Moabs to query for and retrieve (default: 0)')
  option_parser.on('--multipart_druid_sample_count MULTIPART_DRUID_SAMPLE_COUNT',
                   'number of > 10 GB Moabs to query for and retrieve (default: 0)')
  option_parser.on('--endpoints_to_audit ENDPOINTS_TO_AUDIT',
                   'list of cloud endpoints to audit (comma-separated, no spaces, names from config)')
  option_parser.on('--[no-]force_part_md5_comparison', 'Even if the zip parts are not downloaded on this run, compare the previously downloaded MD5 results to what is in the DB')
  option_parser.on('--[no-]dry_run',
                   'Simulate download and fixity check for druid list (defaults to false)')
  option_parser.on('--[no-]quiet', 'Do not output progress information (defaults to false)')
  option_parser.on('-h', '--help', 'Displays help.') do
    $stdout.puts option_parser
    exit
  end
end

parser.parse!(into: options)

exit_code = 0 # we can update if/when we hit problems


logger = ActiveSupport::BroadcastLogger.new(
  Logger.new(Rails.root.join('log', 'audit_archive_zip_checksum_validation.log'))
)
logger.broadcast_to(Logger.new($stdout)) unless options[:quiet]

logger.info('======= FIXITY CHECKING RUN WITH OPTIONS =======')
logger.info("#{options}")
logger.info('======= ******************************** =======')

endpoints_to_audit = options[:endpoints_to_audit].split(',')
fixity_check_base_location = Pathname(options[:fixity_check_base_location])


druids = options[:druid_list].split(',')

if options[:druid_list_file].present? && File.file?(options[:druid_list_file])
  druids += File.readlines(options[:druid_list_file], chomp: true)
end

if options[:single_part_druid_sample_count].positive?
  po_list =
    PreservedObject.joins(
      zipped_moab_versions: [:zip_parts, :zip_endpoint]
    ).group(
      'preserved_objects.druid', 'zip_endpoint.endpoint_name'
    ).having(
      'SUM(zip_parts.size) < :max_size',
      { max_size: ZIP_SEGMENT_THRESHOLD } # we segment zips into 10 GB chunks
    ).order(
      'RANDOM()'
    ).limit(
      options[:single_part_druid_sample_count]
    ).pluck(
      :druid, 'COUNT(zipped_moab_versions.id)', 'zip_endpoint.endpoint_name', 'COUNT(zip_parts.id)', Arel.sql('ARRAY_AGG((version, suffix))'), 'PG_SIZE_PRETTY(SUM(zip_parts.size))', 'SUM(zip_parts.size)'
    )

  total_size = number_to_human_size(po_list.map { |row| row.last }.sum)
  logger.info("sub #{ZIP_SEGMENT_THRESHOLD} GB preserved_objects results (#{total_size} total): #{po_list}")
  druids += po_list.map { |row| row.first }.uniq
end

if options[:multipart_druid_sample_count].positive?
  multipart_zip_po_list =
    PreservedObject.joins(
      zipped_moab_versions: [:zip_parts, :zip_endpoint]
    ).group(
      'preserved_objects.druid', :version, 'zip_endpoint.endpoint_name'
    ).having(
      'SUM(zip_parts.size) > :min_size',
      { min_size: ZIP_SEGMENT_THRESHOLD } # we segment zips into 10 GB chunks
    ).order(
      'RANDOM()'
    ).limit(
      options[:multipart_druid_sample_count]
    ).pluck(
      :druid, :version, 'COUNT(zipped_moab_versions.id)', 'zip_endpoint.endpoint_name', 'COUNT(zip_parts.id)', 'ARRAY_AGG(suffix)', 'PG_SIZE_PRETTY(SUM(zip_parts.size))', 'SUM(zip_parts.size)'
    )

  total_size = number_to_human_size(multipart_zip_po_list.map { |row| row.last }.sum)
  logger.info("over #{ZIP_SEGMENT_THRESHOLD} GB preserved_objects results (#{total_size} total): #{multipart_zip_po_list}")
  druids += multipart_zip_po_list.map { |row| row.first }.uniq
end

if options[:dry_run]
  logger.info("======= DRY RUN =======")
end

logger.info("druids to check: #{druids}")

zp_relation = ZipPart.joins(
  zipped_moab_version: [:preserved_object, :zip_endpoint]
).where(
  preserved_object: { druid: druids },
  zip_endpoint: { endpoint_name: endpoints_to_audit }
).order(:endpoint_name, :druid, :version, :suffix)

zp_relation.pluck(:endpoint_name, :druid, :version, :suffix, :md5, :size).each do |endpoint_name, druid, version, suffix, db_md5, db_size|
  s3_key = Replication::DruidVersionZip.new(druid, version).s3_key(suffix)
  download_path = Pathname(fixity_check_base_location.join(endpoint_name, s3_key))
  s3_object = ZipEndpoint.find_by!(endpoint_name:).bucket.object(s3_key)
  logger.info("=== retrieve #{s3_key} from #{endpoint_name}")
  logger.debug("download_path=#{download_path}")
  logger.debug("download_path.exist?=#{download_path.exist?}")
  logger.debug("download_path.dirname=#{download_path.dirname}")
  logger.debug("download_path.dirname.exist?=#{download_path.dirname.exist?}")
  logger.debug("s3_key=#{s3_key}")
  logger.debug("s3_object.exists?=#{s3_object.exists?}")
  logger.debug("db_md5=#{db_md5}")
  logger.debug("db_size=#{db_size}")
  logger.debug("s3_object.metadata=#{s3_object.metadata}")
  if options[:dry_run]
    logger.info("DRY RUN: skipping download and fresh MD5 computation of #{s3_key} from #{endpoint_name}")
  else
    FileUtils.mkdir_p(download_path.dirname) unless download_path.dirname.exist?
    just_downloaded = false
    unless download_path.exist?
      logger.info("downloading #{s3_key} from #{endpoint_name} (#{number_to_human_size(db_size)} expected)")
      s3_object.download_file(download_path)
      logger.info("downloaded #{s3_key} from #{endpoint_name} (#{number_to_human_size(File.size(download_path.to_s))} retrieved)")
      just_downloaded = true
    else
      logger.info("skipping download of #{s3_key} from #{endpoint_name}, already downloaded")
    end
    if just_downloaded || options[:force_part_md5_comparison]
      logger.info("comparing fresh MD5 calculation to DB value for #{download_path}")
      fresh_md5 = Digest::MD5.file(download_path)
      logger.info("fresh_md5.hexdigest=#{fresh_md5.hexdigest}")
      logger.info("fresh_md5.hexdigest==db_md5: #{fresh_md5.hexdigest==db_md5 ? '✅' : '🚨' }")
    else
      logger.info("skipping comparing fresh MD5 calculation to DB value for #{download_path} (already downloaded, comparison not forced)")
    end
  end
end

zp_relation.where(suffix: '.zip').pluck(:endpoint_name, :druid, :version, :suffix).each do |endpoint_name, druid, version, suffix|
  logger.info("=== unzip #{druid} #{version} from #{endpoint_name}")
  s3_key = Replication::DruidVersionZip.new(druid, version).s3_key(suffix)
  download_path = Pathname(fixity_check_base_location.join(endpoint_name, s3_key))
  if options[:dry_run]
    logger.info("DRY RUN, skipping unzipping #{download_path.basename} in #{download_path.dirname}")
  else
    unzip_filename =
      if Dir.glob("#{download_path.to_s.chomp('zip')}*").size > 1
        "#{download_path.basename.to_s.chomp('zip')}combined.zip".tap do |combined_filename|
          logger.info("multi-part zip, combining into one file (#{combined_filename}) so unzip can handle it")
          if File.exist?("#{download_path.dirname}/#{combined_filename}")
            logger.info("#{download_path.dirname}/#{combined_filename} exists, skipping combining")
          else
            # https://unix.stackexchange.com/questions/40480/how-to-unzip-a-multipart-spanned-zip-on-linux
            logger.info(Open3.capture2e("zip -s 0 #{download_path.basename} --out #{combined_filename}", chdir: download_path.dirname))
          end
        end
      else
        download_path.basename
      end
    logger.info("unzipping #{unzip_filename} in #{download_path.dirname}")
    # TODO: delete option to unzip so that it cleans up after itself?  i don't think that's the default behavior?
    logger.debug(Open3.capture2e("unzip #{unzip_filename}", chdir: download_path.dirname))
  end
end

endpoints_to_audit.each do |endpoint_name|
  druids.each do |druid|
    logger.info("=== fixity check unzipped Moab for #{druid} from #{endpoint_name}")
    storage_location = fixity_check_base_location.join(endpoint_name)
    unless ZippedMoabVersion.joins(:zip_endpoint, :preserved_object).where(preserved_object: { druid: }, zip_endpoint: { endpoint_name: }).exists?
      logger.info("#{endpoint_name} doesn't have any ZMVs for #{druid}, skipping fixity check")
      next
    end

    if options[:dry_run]
      logger.info("DRY RUN, skipping checksum validation for #{druid} in #{storage_location}")
    else
      logger.info "Starting checksum validation for #{druid} in #{storage_location} (NOTE: this may take some time!)"
      checksum_validator = Audit::ChecksumValidator.new(
        logger:,
        moab_storage_object: MoabOnStorage.moab(storage_location:, druid:),
        emit_results: true
      )
      checksum_validator.validate
      exit_code = 1 if checksum_validator.results.error_results.present?
    end
  end
end

exit exit_code
