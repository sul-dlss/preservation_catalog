# frozen_string_literal: true

module Replication
  # Service to replicate a single zip part to cloud endpoint
  class ReplicateZipPartService
    def self.call(...)
      new(...).call
    end

    def initialize(zip_part:)
      @zip_part = zip_part
    end

    # @return [Results] results of the replication attempt possibly including errors
    def call
      set_hb_context

      return results if already_replicated? || !check_existing_part_file_on_endpoint

      transfer_manager.upload_file(zip_part_file.file_path,
                                   bucket: zip_part.zip_endpoint.bucket_name,
                                   key: zip_part.s3_key, metadata:)
      results
    end

    private

    attr_reader :zip_part

    delegate :s3_part, :zip_part_file, :preserved_object, :zip_endpoint, to: :zip_part
    delegate :druid, to: :preserved_object

    def zip_part_file_exists_on_endpoint?
      s3_part.exists?
    end

    def zip_part_md5s_match?
      s3_part.metadata['checksum_md5'] == zip_part.md5
    end

    def already_replicated?
      zip_part_file_exists_on_endpoint? && zip_part_md5s_match?
    end

    def set_hb_context
      Honeybadger.context(
        druid: zip_part.preserved_object.druid,
        version: zip_part.zipped_moab_version.version,
        endpoint: zip_part.zip_endpoint.endpoint_name,
        zip_part_id: zip_part.id
      )
    end

    def metadata
      {
        checksum_md5: zip_part_file.read_md5,
        size: zip_part_file.size.to_s # S3 metadata values must be strings
      }
    end

    def results
      @results ||= Results.new(druid:, moab_storage_root: zip_endpoint, check_name: 'ReplicateZipPartService')
    end

    def check_existing_part_file_on_endpoint
      return true if !zip_part_file_exists_on_endpoint? || zip_part_md5s_match?

      results.add_result(Results::ZIP_PART_CHECKSUM_MISMATCH,
                         endpoint_name: zip_endpoint.endpoint_name,
                         s3_key: zip_part.s3_key,
                         md5: zip_part.md5,
                         replicated_checksum: s3_part.metadata['checksum_md5'],
                         bucket_name: s3_part.bucket_name)
      false
    end

    def transfer_manager
      @transfer_manager ||= Aws::S3::TransferManager.new(
        client: zip_part.zip_endpoint.provider.client
      )
    end
  end
end
