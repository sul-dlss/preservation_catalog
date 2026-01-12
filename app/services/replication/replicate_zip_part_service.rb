# frozen_string_literal: true

module Replication
  # Service to replicate a single zip part to cloud endpoint
  class ReplicateZipPartService
    # Raised when a part file is found at the endpoint and there is an md5 mismatch
    class DifferentPartFileFoundError < StandardError; end

    def self.call(...)
      new(...).call
    end

    def initialize(zip_part:)
      @zip_part = zip_part
    end

    # @raise [DifferentPartFileFoundError] if a different part file is found at the endpoint
    def call
      set_hb_context

      return if already_replicated?
      check_existing_part_file_on_endpoint

      transfer_manager.upload_file(druid_version_zip_part.file_path,
                                   bucket: zip_part.zip_endpoint.bucket_name,
                                   key: zip_part.s3_key, metadata:)
    end

    private

    attr_reader :zip_part

    delegate :s3_part, :druid_version_zip_part, to: :zip_part

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
        checksum_md5: druid_version_zip_part.read_md5,
        size: druid_version_zip_part.size.to_s # S3 metadata values must be strings
      }
    end

    def check_existing_part_file_on_endpoint
      raise DifferentPartFileFoundError if zip_part_file_exists_on_endpoint? && !zip_part_md5s_match?
    end

    def transfer_manager
      @transfer_manager ||= Aws::S3::TransferManager.new(
        client: zip_part.zip_endpoint.provider.client
      )
    end
  end
end
