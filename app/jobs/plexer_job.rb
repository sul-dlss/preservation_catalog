# Responsibilities:
# Record zip metadata info in DB.
# Split message out to all necessary endpoints.
# For example:
#   Endpoint1Delivery.perform_later(druid, version)
#   Endpoint2Delivery.perform_later(druid, version)
#   ...
#
# Do not assume we can just get metadata from (the DruidVersionZip) zip.
# Jobs are not run at the same time or on the same system, so the info will not match.
# Therefore, we receive the info passed by the process that was there when the file was created.
class PlexerJob < DruidVersionJobBase
  queue_as :zips_made

  before_enqueue { |job| job.zip_info_check!(job.arguments.third) }

  # @param [String] druid
  # @param [Integer] version
  # @param [Hash<Symbol => String>] metadata Zip info
  # @option metadata [Integer] :size
  # @option metadata [String] :checksum_md5
  # @option metadata [String] :zip_cmd
  # @option metadata [String] :zip_version
  def perform(druid, version, metadata)
    ApplicationRecord.transaction do
      update_size(metadata[:size])
      pcs.each do |pc|
        pc.zip_checksums.find_or_create_by!(
          md5: metadata[:checksum_md5],
          create_info: metadata.slice(:zip_cmd, :zip_version).to_s
        )
      end
    end
    targets(pcs.pluck(:endpoint_id)).each { |worker| worker.perform_later(druid, version, metadata) }
  end

  # @return [PreservedCopy::ActiveRecord_Relation]
  def pcs
    @pcs ||= PreservedCopy.by_druid(zip.druid.id).for_archive_endpoints.where(version: zip.version)
  end

  # @param [Array<Integer>] endpoint_ids
  # @return [Array<Class>] Endpoint delivery classes to be targeted
  def targets(endpoint_ids)
    Endpoint
      .where(id: endpoint_ids)
      .group(:delivery_class, :id)
      .pluck(:delivery_class, :id)
      .map do |pair|
        Rails.logger.error("Archive Endpoint (id: #{pair.second}) has no delivery_class") unless pair.first
        pair.first
      end.compact
  end

  # Validate the incoming value and save once for all
  # @param [Integer] size
  def update_size(size)
    raise ArgumentError, "Size should be an Integer, not #{size.class}" unless size.is_a?(Integer)
    raise ArgumentError, "Inavlid size value '#{size}'" unless size > 0
    pcs.update_all(size: size) # rubocop:disable Rails/SkipsModelValidations
  end
end
