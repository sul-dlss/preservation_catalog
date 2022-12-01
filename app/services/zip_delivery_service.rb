# frozen_string_literal: true

# Posts zips to S3, if needed.
class ZipDeliveryService
  def self.deliver(...)
    new(...).deliver
  end

  # @param [Aws::S3::Object] s3_part
  # @param [Replication::DruidVersionZipPart] dvz_part
  # @param [Hash<Symbol => String, Integer>] metadata Zip info
  def initialize(s3_part:, dvz_part:, metadata:)
    @s3_part = s3_part
    @dvz_part = dvz_part
    @metadata = stringify_values(metadata)
  end

  def deliver # rubocop:disable Metrics/AbcSize
    if s3_part.exists?
      msg = 'WARNING: S3 location already has content. ' \
            'Perhaps a failed replication was pruned from the database, but was not removed from the cloud. ' \
            "If so, prune this content from the database again (there's a rake task), ask ops to delete the bad replicated content, and try again."
      hb_context = {
        druid: dvz_part.druid.druid, # dvz_part.dvz.druid is a DruidTools::Druid object
        version: dvz_part.dvz.version,
        endpoint: s3_part.bucket_name
      }
      Honeybadger.notify(msg, context: hb_context)
      Rails.logger.warn("msg: #{msg}, context: #{hb_context}")

      # retries will fail and as nothing was delivered, we do NOT want to proceed with replication job sequence.
      return
    end

    raise "#{s3_part.key} MD5 mismatch: passed #{given_md5}, computed #{fresh_md5}" if fresh_md5 != given_md5

    s3_part.upload_file(dvz_part.file_path, metadata: metadata)
  end

  private

  attr_reader :dvz_part, :metadata, :s3_part

  # coerce size int to string (all values must be strings)
  # @param [Hash<Symbol => #to_s>] metadata
  # @return [Hash<Symbol => String>] metadata
  def stringify_values(metadata)
    metadata.merge(size: metadata[:size].to_s, parts_count: metadata[:parts_count].to_s)
  end

  def fresh_md5
    dvz_part.read_md5
  end

  def given_md5
    metadata[:checksum_md5]
  end
end
