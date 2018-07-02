# We chunk archives of Moab versions into multiple files, so we don't get
# completely unwieldy file sizes.  This represents metadata for one such part.
class ArchivePreservedCopyPart < ApplicationRecord
  belongs_to :archive_preserved_copy

  validates :archive_preserved_copy, :create_info, presence: true
  validates :md5, presence: true, format: { with: /\A[0-9a-f]{32}\z/ }
  validates :size, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
