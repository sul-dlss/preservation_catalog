# frozen_string_literal: true

# We chunk archives of Moab versions into multiple files, so we don't get
# completely unwieldy file sizes.  This represents metadata for one such part.
# This model's data is populated by Replication::DeliveryDispatcherJob.
class ZipPart < ApplicationRecord
  belongs_to :zipped_moab_version, inverse_of: :zip_parts
  delegate :zip_endpoint, :preserved_object, :druid_version_zip, to: :zipped_moab_version

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

  def druid_version_zip_part
    @druid_version_zip_part ||= Replication::DruidVersionZipPart.new(druid_version_zip, s3_key)
  end

  def s3_key
    druid_version_zip.s3_key(suffix)
  end

  def s3_part
    @s3_part ||= zip_endpoint.bucket.object(s3_key)
  end
end
