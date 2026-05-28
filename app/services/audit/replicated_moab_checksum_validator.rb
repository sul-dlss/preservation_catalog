# frozen_string_literal: true

module Audit
  # This service class provides tools for retrieving and fixity checking
  # archived Moabs (stored as zipped moab versions in S3 buckets, possibly
  # with multi-part zip files for larger Moab versions).
  #
  # USAGE NOTES:
  #   * Look at the logs to tell you how the run went!
  #   * This code works synchronously. It downloads and checksum validates arbitrarily
  #     large SDR objects. For anything long running, run via screen or ActiveJob.
  #   * In practice, as of May 2026, this won't be able to retrieve most of our
  #     content on AWS endpoints, because that content gets moved to Glacier after
  #     upload, and a request must be made to restore it to a temp S3 bucket for
  #     retrieval. GCP-stored content should not have that issue, and should be immediately
  #     retrievable from the location to which it was initially uploaded.
  #     See https://docs.aws.amazon.com/AmazonS3/latest/userguide/restoring-objects.html
  #   * A further possible manual check, and an opportunity to add functionality to this class: compare
  #     the hash of each manifestInventory.xml with corresponding file in on prem Moab.  This file contains
  #     checksums for each manifest file in the version, including signatureCatalog.xml, which contains checksums
  #     for each SDR content and metadata file for its version.
  class ReplicatedMoabChecksumValidator # rubocop:disable Metrics/ClassLength
    include ActionView::Helpers::NumberHelper
    extend ActionView::Helpers::NumberHelper

    attr_accessor :fixity_check_base_location

    # @param [Pathname] fixity_check_base_location target directory for downloading cloud archived Moabs
    # @param [Boolean] dry_run if true, do not actually download or checksum validate
    # @param [Boolean] force_part_md5_comparison Even if the zip parts are not downloaded on this run, compare
    #  the previously downloaded MD5 results to what is in the DB
    # @param [Logger] additional_logger an additional logger for this object to broadcast to
    def initialize(fixity_check_base_location:, dry_run:, force_part_md5_comparison:, additional_logger: nil)
      @fixity_check_base_location = fixity_check_base_location
      @dry_run = dry_run
      @force_part_md5_comparison = force_part_md5_comparison
      @transfer_managers = {}
      logger.broadcast_to(additional_logger) if additional_logger
    end

    def logger
      @logger ||= ActiveSupport::BroadcastLogger.new(
        Audit::ReplicationSupport.logger
      )
    end

    # @param [Array<String>] endpoints_to_audit
    # @param [Array<String>] druids
    def validate_replicated_moab_checksums!(endpoints_to_audit:, druids:)
      logger.info('======= DRY RUN =======') if dry_run?

      logger.info("druids to check: #{druids}")

      zip_part_relation =
        ZipPart.joins(
          zipped_moab_version: %i[preserved_object zip_endpoint]
        ).where(
          preserved_object: { druid: druids },
          zip_endpoint: { endpoint_name: endpoints_to_audit }
        ).order(:endpoint_name, :druid, :version, :suffix)

      download_zip_parts(fixity_check_base_location:, zip_part_relation:)
      unzip_downloaded_zip_parts(zip_part_relation:)
      fixity_check_unzipped_moabs(endpoints_to_audit:, druids:)
    end

    # obtain a random sampling of druids for which each ZippedMoabVersion row
    # has only one ZipPart
    def self.druids_having_single_part_versions(sample_count, logger: nil)
      logger ||= Audit::ReplicationSupport.logger

      # look for druids with nothing but single part zips, one part per replicated version
      having_clause = 'COUNT(DISTINCT(zip_parts.id)) = COUNT(DISTINCT(zipped_moab_versions.id))'

      po_list = preserved_object_sample_query(sample_count:, having_clause:).pluck(
        :druid, :current_version, 'COUNT(DISTINCT(zipped_moab_versions.id))',
        'COUNT(DISTINCT(zip_parts.id))', 'PG_SIZE_PRETTY(SUM(zip_parts.size))',
        'SUM(zip_parts.size)'
      )

      total_size = number_to_human_size(po_list.map(&:last).sum)
      logger.info("query results: preserved_objects with only single-part zips: (#{total_size} total): #{po_list}")
      po_list.map(&:first).uniq
    end

    # obtain a random sampling of druids where at least one of each druid's
    # ZippedMoabVersion rows has more than one ZipPart (i.e. each druid has at
    # least one archive zip split into multiple parts)
    def self.druids_having_a_multi_part_version(sample_count, logger: nil)
      logger ||= Audit::ReplicationSupport.logger

      # look for druids with at least one multi-part zip, i.e. more parts than replicated versions
      having_clause = 'COUNT(DISTINCT(zip_parts.id)) > COUNT(DISTINCT(zipped_moab_versions.id))'

      po_list = preserved_object_sample_query(sample_count:, having_clause:).pluck(
        :druid, :current_version, 'COUNT(DISTINCT(zipped_moab_versions.id))',
        'COUNT(DISTINCT(zip_parts.id))', 'PG_SIZE_PRETTY(SUM(zip_parts.size))',
        'SUM(zip_parts.size)'
      )

      total_size = number_to_human_size(po_list.map(&:last).sum)
      logger.info("query results: preserved_objects with at least one multi-part zip: (#{total_size} total): #{po_list}")
      po_list.map(&:first).uniq
    end

    private

    private_class_method def self.preserved_object_sample_query(sample_count:, having_clause:)
      PreservedObject.joins(
        zipped_moab_versions: [:zip_parts]
      ).group(
        'preserved_objects.id'
      ).having(
        having_clause
      ).order(
        'RANDOM()'
      ).limit(
        sample_count
      )
    end

    def force_part_md5_comparison?
      @force_part_md5_comparison
    end

    def dry_run?
      @dry_run
    end

    def transfer_manager(zip_endpoint:)
      @transfer_managers[zip_endpoint.endpoint_name] ||= Aws::S3::TransferManager.new(
        client: zip_endpoint.provider.client
      )
    end

    # @param [Pathname] download_path
    # @param [ZipPart] zip_part
    def download_zip_part(download_path:, zip_part:) # rubocop:disable Metrics/AbcSize
      endpoint_name = zip_part.zip_endpoint.endpoint_name
      db_md5 = zip_part.md5
      db_size = zip_part.size
      s3_key = zip_part.s3_key

      FileUtils.mkdir_p(download_path.dirname) unless download_path.dirname.exist?
      just_downloaded = false
      if download_path.exist?
        logger.info("skipping download of #{s3_key} from #{endpoint_name}, already downloaded")
      else
        zip_endpoint = zip_part.zip_endpoint
        transfer_manager = transfer_manager(zip_endpoint:)
        logger.info("downloading #{s3_key} from #{endpoint_name} (#{number_to_human_size(db_size)} expected)")
        transfer_manager.download_file(download_path, bucket: zip_endpoint.bucket.name, key: s3_key)
        logger.info("downloaded #{s3_key} from #{endpoint_name} (#{number_to_human_size(File.size(download_path.to_s))} retrieved)")
        just_downloaded = true
      end

      if just_downloaded || force_part_md5_comparison?
        logger.info("comparing fresh MD5 calculation to DB value for #{download_path}")
        fresh_md5 = Digest::MD5.file(download_path)
        logger.info("fresh_md5.hexdigest=#{fresh_md5.hexdigest}")
        logger.info("fresh_md5.hexdigest==db_md5: #{fresh_md5.hexdigest == db_md5 ? '✅' : '🚨'}")
      else
        logger.info("skipping comparing fresh MD5 calculation to DB value for #{download_path} (already downloaded, comparison not forced)")
      end
    end

    # @param [Pathname] fixity_check_base_location
    # @param [ActiveRecord::Relation] zip_part_relation The zip parts that will be downloaded and inflated into
    #  Moab directories
    def download_zip_parts(fixity_check_base_location:, zip_part_relation:) # rubocop:disable Metrics/AbcSize
      zip_part_relation.find_each do |zip_part|
        endpoint_name = zip_part.zip_endpoint.endpoint_name
        db_md5 = zip_part.md5
        db_size = zip_part.size
        s3_key = zip_part.s3_key
        download_path = Pathname(fixity_check_base_location.join(endpoint_name, s3_key))
        s3_object = zip_part.s3_part

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

        if dry_run?
          logger.info("DRY RUN: skipping download and fresh MD5 computation of #{s3_key} from #{endpoint_name}")
        else
          download_zip_part(download_path:, zip_part:)
        end
      end
    end

    # @param [Pathname] download_path the path to which the .zip file was downloaded
    def unzip_zipped_moab_version_from_zip_parts(download_path:)
      unzip_filename = download_path.basename

      logger.info("unzipping #{unzip_filename} in #{download_path.dirname}")
      logger.debug(Open3.capture2e("7z x #{unzip_filename}", chdir: download_path.dirname))
    end

    # @param [ActiveRecord::Relation] zip_part_relation The zip parts that will be downloaded and inflated into
    #  Moab directories
    def unzip_downloaded_zip_parts(zip_part_relation:) # rubocop:disable Metrics/AbcSize
      zip_part_relation.where(suffix: '.zip').find_each do |zip_part|
        endpoint_name = zip_part.zip_endpoint.endpoint_name
        druid = zip_part.preserved_object.druid
        version = zip_part.zipped_moab_version.version
        s3_key = zip_part.s3_key

        logger.info("=== unzip #{druid} #{version} from #{endpoint_name}")
        download_path = Pathname(fixity_check_base_location.join(endpoint_name, s3_key))
        if dry_run?
          logger.info("DRY RUN, skipping unzipping #{download_path.basename} in #{download_path.dirname}")
        else
          unzip_zipped_moab_version_from_zip_parts(download_path:)
        end
      end
    end

    # @param [Array<String>] endpoints_to_audit
    # @param [Array<String>] druids
    def fixity_check_unzipped_moabs(endpoints_to_audit:, druids:) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      results_objects = []

      endpoints_to_audit.each do |endpoint_name|
        druids.each do |druid|
          logger.info("=== fixity check unzipped Moab for #{druid} from #{endpoint_name}")
          storage_location = fixity_check_base_location.join(endpoint_name)
          unless ZippedMoabVersion.joins(:zip_endpoint, :preserved_object).exists?(preserved_object: { druid: },
                                                                                   zip_endpoint: { endpoint_name: })
            logger.info("#{endpoint_name} doesn't have any ZMVs for #{druid}, skipping fixity check")
            next
          end

          if dry_run?
            logger.info("DRY RUN, skipping checksum validation for #{druid} in #{storage_location}")
          else
            logger.info "Starting checksum validation for #{druid} in #{storage_location} (NOTE: this may take some time!)"
            checksum_validator = Audit::ChecksumValidator.new(
              logger:,
              moab_storage_object: MoabOnStorage.moab(storage_location:, druid:),
              emit_results: true
            )
            checksum_validator.validate
            results_objects << checksum_validator.results
          end
        end
      end

      results_objects
    end
  end
end
