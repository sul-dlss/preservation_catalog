# frozen_string_literal: true

module Audit
  # Methods to support auditing replication.
  class ReplicationSupport
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
               [
                 zip_part.preserved_object.druid,
                 zip_part.preserved_object.current_version,
                 zip_part.zipped_moab_version.version,
                 zip_part.zip_endpoint.endpoint_name,
                 zip_part.status,
                 zip_part.suffix,
                 zip_part.parts_count,
                 zip_part.size,
                 zip_part.md5,
                 zip_part.id,
                 zip_part.created_at,
                 zip_part.updated_at,
                 zip_part.s3_key,
                 s3_part_exists ? 'found at endpoint' : 'not found at endpoint',
                 s3_part_exists ? s3_part.metadata['checksum_md5'] : nil
               ]
      end
    end
  end
end
