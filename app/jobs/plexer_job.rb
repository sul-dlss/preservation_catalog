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
class PlexerJob < ZipPartJobBase
  queue_as :zips_made

  before_enqueue { |job| job.zip_info_check!(job.arguments.fourth) }

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
    apcs.each do |apc|
      find_or_create_unreplicated_part(apc, part_s3_key, metadata)
    end
    deliverers.each { |worker| worker.perform_later(druid, version, part_s3_key, metadata) }
  end

  private

  # @return [ActiveRecord::Relation] effectively an Array of ArchivePreservedCopy objects
  def apcs
    @apcs ||= ArchivePreservedCopy.by_druid(zip.druid.id).where(version: zip.version)
  end

  def find_or_create_unreplicated_part(apc, part_s3_key, metadata)
    apc.zip_parts.find_or_create_by(
      create_info: metadata.slice(:zip_cmd, :zip_version).to_s,
      md5: metadata[:checksum_md5],
      parts_count: metadata[:parts_count],
      size: metadata[:size],
      suffix: File.extname(part_s3_key)
    ) { |part| part.unreplicated! }
  end

  # @return [Array<Class>] target delivery worker classes
  def deliverers
    apcs.map { |apc| apc.archive_endpoint.delivery_class }.uniq
  end
end
