# frozen_string_literal: true

# We chunk archives of Moab versions into multiple files, so we don't get
# completely unwieldy file sizes.  This represents metadata for one such part.
# This model's data is populated by Replication::DeliveryDispatcherJob.
class ZipPart < ApplicationRecord
  belongs_to :zipped_moab_version, inverse_of: :zip_parts

  delegate :zip_endpoint, :preserved_object, :druid_version_zip, to: :zipped_moab_version
  delegate :druid, to: :preserved_object
  delegate :endpoint_name, to: :zip_endpoint

  # @note Hash values cannot be modified without migrating any associated persisted data.
  # @see [enum docs] http://api.rubyonrails.org/classes/ActiveRecord/Enum.html
  enum :status, {
    'ok' => 0,
    'unreplicated' => 1, # DB-level default
    'not_found' => 2,
    'replicated_checksum_mismatch' => 3
  }

  validates :create_info, presence: true
  validates :md5, presence: true, format: { with: /\A[0-9a-f]{32}\z/ }
  validates :size, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :suffix, presence: true, format: { with: /\A\.z(ip|[0-9]+)\z/ }
  validates :parts_count, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # For this persisted ZipPart, are it and all its sibling parts now replicated
  #  to their parent ZippedMoabVersion's ZipEndpoint?
  # @return [Boolean] true if all expected parts are now replicated
  def all_parts_replicated?
    return false unless persisted? && ok?
    parts = zipped_moab_version.zip_parts.where(suffix: suffixes_in_set)
    parts.count == parts_count && parts.all?(&:ok?)
  end

  # For this part, the suffixes of all parts constituting the full zip
  # @return [Array<String>]
  def suffixes_in_set
    druid_version_zip.expected_part_keys(parts_count).map { |key| File.extname(key) }
  end

  def druid_version_zip_part
    @druid_version_zip_part ||= Replication::DruidVersionZipPart.new(druid_version_zip, s3_key)
  end

  def s3_key
    druid_version_zip.s3_key(suffix)
  end

  def s3_part
    @s3_part ||= zip_endpoint.bucket.object(s3_key)
  end

  def to_h # rubocop:disable Metrics/AbcSize
    {
      druid: preserved_object.druid,
      preserved_object_version: preserved_object.current_version,
      zipped_moab_version: zipped_moab_version.version,
      endpoint_name:,
      status:,
      suffix:,
      parts_count:,
      size:,
      md5:,
      id:,
      created_at:,
      updated_at:,
      s3_key:,
      found_at_endpoint:,
      checksum_md5:
    }
  end

  def found_at_endpoint
    return 'not found at endpoint' unless s3_part.exists?

    'found at endpoint'
  end

  def checksum_md5
    return nil unless s3_part.exists?

    s3_part.metadata['checksum_md5']
  end

  def to_honeybadger_context
    to_h
  end
end
