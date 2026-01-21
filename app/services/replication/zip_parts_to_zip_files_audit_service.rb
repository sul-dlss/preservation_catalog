# frozen_string_literal: true

module Replication
  # Compare the md5s of ZipParts against zip files on disk
  class ZipPartsToZipFilesAuditService
    def self.call(...)
      new(...).call
    end

    def initialize(zipped_moab_version:)
      @zipped_moab_version = zipped_moab_version
    end

    def call
      zipped_moab_version.zip_parts.each do |zip_part|
        next if zip_part.md5 == (local_md5 = zip_part.druid_version_zip_part.read_md5)

        results.add_result(Results::ZIP_PART_CHECKSUM_FILE_MISMATCH, s3_key: zip_part.s3_key,
                                                                     md5: zip_part.md5,
                                                                     local_md5:)
      end

      results
    end

    private

    attr_reader :zipped_moab_version

    def results
      @results ||= Results.new(druid: zipped_moab_version.preserved_object.druid,
                               moab_storage_root: zipped_moab_version.zip_endpoint,
                               check_name: 'ZipPartsToZipFilesAudit')
    end
  end
end
