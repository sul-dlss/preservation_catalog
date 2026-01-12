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
               bucket = zip_part.zip_endpoint.delivery_class.constantize.new.bucket
               s3_part = bucket.object(zip_part.s3_key)
               s3_part_exists = s3_part.exists?
               {
                 druid: zip_part.preserved_object.druid,
                 preserved_object_version: zip_part.preserved_object.current_version,
                 zipped_moab_version: zip_part.zipped_moab_version.version,
                 endpoint_name: zip_part.zip_endpoint.endpoint_name,
                 status: zip_part.status,
                 suffix: zip_part.suffix,
                 parts_count: zip_part.parts_count,
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
  end
end
