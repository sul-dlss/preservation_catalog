# frozen_string_literal: true

module Audit
  # Methods to support auditing replication.
  class ReplicationSupport
    include ActionView::Helpers::NumberHelper

    def self.logger
      @logger ||= Logger.new(Rails.root.join('log', 'c2a.log'))
    end

    # a helpful query for debugging replication issues
    # @param [String|Array<String>] druid
    # @return [Array<Array>] an array of zip part debug info
    def self.zip_part_debug_info(druid)
      ZipPart.joins(zipped_moab_version: %i[preserved_object zip_endpoint])
             .where(preserved_objects: { druid: druid })
             .order(:druid, :version, :endpoint_name, :suffix)
             .map do |zip_part|
        s3_part = zip_part.s3_part
        s3_part_exists = s3_part.exists?
        {
          druid: zip_part.preserved_object.druid,
          preserved_object_version: zip_part.preserved_object.current_version,
          zipped_moab_version: zip_part.zipped_moab_version.version,
          endpoint_name: zip_part.zip_endpoint.endpoint_name,
          status: zip_part.zipped_moab_version.status,
          suffix: zip_part.suffix,
          parts_count: zip_part.zipped_moab_version.zip_parts_count,
          size: zip_part.size,
          md5: zip_part.md5,
          id: zip_part.id,
          created_at: zip_part.created_at,
          updated_at: zip_part.updated_at,
          s3_key: zip_part.s3_key,
          found_at_endpoint: s3_part_exists ? 'found at endpoint' : 'not found at endpoint',
          checksum_md5: s3_part_exists ? s3_part.metadata['checksum_md5'] : nil
        }
      end
    end

    # @param [Pathname] download_path
    # @param [String] s3_key
    # @param [Aws::S3::Object] s3_object
    # @param [String] endpoint_name
    # @param [Integer] db_size
    # @param [String] db_md5
    # @param [Boolean] force_part_md5_comparison
    # @param [ActiveSupport::BroadcastLogger] download_logger
    # TODO: could start by taking in s3_key and s3_object for simplicity of refactor,
    #   but should switch to taking in bucket and making a TransferManager, or taking a
    #   ZipPart and using ReplicateZipPartService to get a transfer manager
    #   see https://github.com/sul-dlss/preservation_catalog/pull/2526/changes and
    #   https://www.rubydoc.info/gems/aws-sdk-s3/1.208.0/Aws/S3/TransferManager:download_file
    def self.download_zip_part(download_path:, s3_key:, s3_object:, endpoint_name:, db_size:, db_md5:, force_part_md5_comparison:, download_logger: nil) # rubocop:disable Metrics/PerceivedComplexity,Metrics/ParameterLists
      download_logger ||= ActiveSupport::BroadcastLogger.new
      download_logger.broadcast_to(logger)

      FileUtils.mkdir_p(download_path.dirname) unless download_path.dirname.exist?
      just_downloaded = false
      if download_path.exist?
        download_logger.info("skipping download of #{s3_key} from #{endpoint_name}, already downloaded")
      else
        download_logger.info("downloading #{s3_key} from #{endpoint_name} (#{number_to_human_size(db_size)} expected)")
        s3_object.download_file(download_path)
        download_logger.info("downloaded #{s3_key} from #{endpoint_name} (#{number_to_human_size(File.size(download_path.to_s))} retrieved)")
        just_downloaded = true
      end

      if just_downloaded || force_part_md5_comparison
        download_logger.info("comparing fresh MD5 calculation to DB value for #{download_path}")
        fresh_md5 = Digest::MD5.file(download_path)
        download_logger.info("fresh_md5.hexdigest=#{fresh_md5.hexdigest}")
        download_logger.info("fresh_md5.hexdigest==db_md5: #{fresh_md5.hexdigest == db_md5 ? '✅' : '🚨'}")
      else
        download_logger.info("skipping comparing fresh MD5 calculation to DB value for #{download_path} (already downloaded, comparison not forced)")
      end
    end

    # @param [Pathname] download_path
    # @param [ActiveSupport::BroadcastLogger] unzip_logger
    def self.unzip_zipped_moab_version_from_zip_parts(download_path:, unzip_logger:)
      unzip_logger ||= ActiveSupport::BroadcastLogger.new
      unzip_logger.broadcast_to(logger)

      # unzip_filename =
      #   if Dir.glob("#{download_path.to_s.chomp('zip')}*").size > 1
      #     "#{download_path.basename.to_s.chomp('zip')}combined.zip".tap do |combined_filename|
      #       unzip_logger.info("multi-part zip, combining into one file (#{combined_filename}) so unzip can handle it")
      #       if File.exist?("#{download_path.dirname}/#{combined_filename}")
      #         unzip_logger.info("#{download_path.dirname}/#{combined_filename} exists, skipping combining")
      #       else
      #         # https://unix.stackexchange.com/questions/40480/how-to-unzip-a-multipart-spanned-zip-on-linux
      #         unzip_logger.info(Open3.capture2e("zip -s 0 #{download_path.basename} --out #{combined_filename}", chdir: download_path.dirname))
      #       end
      #     end
      #   else
      #     download_path.basename
      #   end
      unzip_filename = download_path.basename

      unzip_logger.info("unzipping #{unzip_filename} in #{download_path.dirname}")
      # TODO: delete option to unzip so that it cleans up after itself?  i don't think that's the default behavior?
      # unzip_logger.debug(Open3.capture2e("unzip #{unzip_filename}", chdir: download_path.dirname))
      unzip_logger.debug(Open3.capture2e("7z x #{unzip_filename}", chdir: download_path.dirname))
    end
  end
end
