##
# ZipChecksum contains the MD5 checksum and creation info for every preserved copy (druid, version)
# that has been archived.
class ZipChecksum < ApplicationRecord
  belongs_to :preserved_copy

  validates :preserved_copy, presence: true
  validates :md5, presence: true, format: { with: /\A[0-9a-f]{32}\z/ }
  validates :create_info, presence: true
end
