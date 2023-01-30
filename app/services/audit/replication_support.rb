# frozen_string_literal: true

module Audit
  # Methods to support auditing replication.
  class ReplicationSupport
    def self.logger
      @logger ||= Logger.new(Rails.root.join('log', 'c2a.log'))
    end

    # @return [Boolean] true if we have a list of child parts to check in the cloud, false otherwise
    def self.check_child_zip_part_attributes(zmv, results)
      base_hash = { version: zmv.version, endpoint_name: zmv.zip_endpoint.endpoint_name }
      unless zmv.zip_parts.count.positive?
        results.add_result(Audit::Results::ZIP_PARTS_NOT_CREATED, base_hash)
        return false # everything else relies on checking parts, nothing left to do
      end

      total_part_size = zmv.total_part_size
      moab_version_size = zmv.preserved_object.total_size_of_moab_version(zmv.version)
      if total_part_size < moab_version_size
        results.add_result(
          Audit::Results::ZIP_PARTS_SIZE_INCONSISTENCY,
          base_hash.merge(total_part_size: total_part_size, moab_version_size: moab_version_size)
        )
      end

      child_parts_counts = zmv.child_parts_counts
      if child_parts_counts.length > 1
        results.add_result(
          Audit::Results::ZIP_PARTS_COUNT_INCONSISTENCY,
          base_hash.merge(child_parts_counts: child_parts_counts)
        )
      elsif child_parts_counts.length == 1 && child_parts_counts.first.first != zmv.zip_parts.length
        results.add_result(
          Audit::Results::ZIP_PARTS_COUNT_DIFFERS_FROM_ACTUAL,
          base_hash.merge(db_count: child_parts_counts.first.first, actual_count: zmv.zip_parts.length)
        )
      end

      unreplicated_parts = zmv.zip_parts.where(status: :unreplicated)
      if unreplicated_parts.count.positive?
        results.add_result(
          Audit::Results::ZIP_PARTS_NOT_ALL_REPLICATED,
          base_hash.merge(unreplicated_parts_list: unreplicated_parts.to_a)
        )
      end

      true
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
