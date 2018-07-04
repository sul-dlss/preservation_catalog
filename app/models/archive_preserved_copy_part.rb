# We chunk archives of Moab versions into multiple files, so we don't get
# completely unwieldy file sizes.  This represents metadata for one such part.
# This model's data is populated by PlexerJob.
class ArchivePreservedCopyPart < ApplicationRecord
  belongs_to :archive_preserved_copy, inverse_of: :archive_preserved_copy_parts
  delegate :archive_endpoint, :preserved_copy, to: :archive_preserved_copy
  delegate :preserved_object, to: :preserved_copy

  validates :archive_preserved_copy, :create_info, presence: true
  validates :md5, presence: true, format: { with: /\A[0-9a-f]{32}\z/ }
  validates :size, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :suffix, presence: true, format: { with: /\A\.z(ip|[0-9]+)\z/ }
  validates :parts_count, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # after_create :deliver!
  #
  # # asynchronously post the new zip part to the target endpoint
  # def deliver!
  #   dvz = DruidVersionZip.new(preserved_object.druid, archive_preserved_copy.version)
  #   archive_endpoint.delivery_class.perform_later(
  #     dvz.druid.id,
  #     dvz.version,
  #     dvz.s3_key(suffix),
  #     metadata...
  #   )
  # end
end
