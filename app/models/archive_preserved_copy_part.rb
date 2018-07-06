# We chunk archives of Moab versions into multiple files, so we don't get
# completely unwieldy file sizes.  This represents metadata for one such part.
# This model's data is populated by PlexerJob.
class ArchivePreservedCopyPart < ApplicationRecord
  belongs_to :archive_preserved_copy, inverse_of: :archive_preserved_copy_parts
  delegate :archive_endpoint, :preserved_copy, to: :archive_preserved_copy
  delegate :preserved_object, to: :preserved_copy

  enum status: {
    'ok' => 0,
    'unreplicated' => 1 # DB-level default
  }

  validates :archive_preserved_copy, :create_info, presence: true
  validates :md5, presence: true, format: { with: /\A[0-9a-f]{32}\z/ }
  validates :size, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :suffix, presence: true, format: { with: /\A\.z(ip|[0-9]+)\z/ }
  validates :parts_count, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # For this persisted part, are it and all its cohort now replicated (to one endpoint)?
  # @return [Boolean] true if all expected parts are now replicated
  def all_parts_replicated?
    return false unless persisted? && ok?
    suffixes = DruidVersionZip
                 .new(preserved_object.druid, preserved_copy.version)
                 .expected_part_keys(parts_count)
                 .map { |key| File.extname(key) }
    parts = archive_preserved_copy.archive_preserved_copy_parts.where(suffix: suffixes)
    parts.count == parts_count && parts.all?(:ok?)
  end
end
