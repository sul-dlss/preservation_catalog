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
      Honeybadger.context(zip_part:)

      return if already_replicated?
      check_existing_part_file_on_endpoint

      s3_part.upload_file(druid_version_zip_part.file_path, metadata:)
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

    def metadata
      {
        checksum_md5: druid_version_zip_part.read_md5,
        size: druid_version_zip_part.size.to_s # S3 metadata values must be strings
      }
    end

    def check_existing_part_file_on_endpoint
      raise DifferentPartFileFoundError if zip_part_file_exists_on_endpoint? && !zip_part_md5s_match?
    end
  end
end
