# Preconditions:
#  All needed PreservedCopy and ArchivePreservedCopy rows are already made.
#  Possible TODO: replace precondition w/ invocation of PO2PC/PC2APC method.
#
# Responsibilities:
# Record zip part metadata info in DB.
# Split message out to all necessary endpoints.
# For example:
#   Endpoint1Delivery.perform_later(druid, version, part_s3_key)
#   Endpoint2Delivery.perform_later(druid, version, part_s3_key)
#   ...
#
# Do not assume we can just get metadata from (the DruidVersionZip) zip.
# Jobs are not run at the same time or on the same system, so the info may not match.
# Therefore, we receive the info passed by the process that was there when the file was created.
class PlexerJob < DruidVersionJobBase
  queue_as :zips_made

  before_enqueue { |job| job.zip_info_check!(job.arguments.third) }

  # @param [String] druid
  # @param [Integer] version
  # @param [String] part_s3_key, e.g. 'ab/123/cd/4567/ab123cd4567.v0001.z03'
  # @param [Hash<Symbol => String>] metadata Zip info
  # @option metadata [Integer] :parts_count
  # @option metadata [Integer] :size
  # @option metadata [String] :checksum_md5
  # @option metadata [String] :suffix
  # @option metadata [String] :zip_cmd
  # @option metadata [String] :zip_version
  def perform(druid, version, part_s3_key, metadata)
    # dvz_part = DruidVersionZipPart.new(zip, part_s3_key)
    apcs.each do |apc|
      apc.archive_preserved_copy_parts.find_or_create_by(
        create_info: metadata.slice(:zip_cmd, :zip_version).to_s,
        md5: metadata[:checksum_md5],
        parts_count: metadata[:parts_count],
        size: metadata[:size],
        suffix: metadata[:suffix]
      )
    end
    apcs.map { |apc| apc.archive_endpoint.delivery_class }.uniq.each do |worker|
      worker.perform_later(druid, version, part_s3_key, metadata)
    end
  end

  # @return [PreservedCopy]
  def apcs
    @apcs ||= PreservedCopy.by_druid(zip.druid.id).first!.archive_preserved_copies.where(version: zip.version)
  end
end
