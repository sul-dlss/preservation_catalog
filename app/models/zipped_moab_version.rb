# frozen_string_literal: true

# Corresponds to a Moab-Version on a ZipEndpoint.
#   There will be individual parts (at least one) - see ZipPart.
# For a fully consistent system, given a PreservedObject, the number of associated
# ZippedMoabVersion objects should be:
#   preserved_object.current_version * ZipEndpoint.count
#
# @note Does not have size independent of part(s), see `#total_part_size`
class ZippedMoabVersion < ApplicationRecord
  belongs_to :preserved_object, inverse_of: :zipped_moab_versions
  belongs_to :zip_endpoint, inverse_of: :zipped_moab_versions
  has_many :zip_parts, dependent: :restrict_with_exception, inverse_of: :zipped_moab_version

  validates :version, presence: true

  scope :by_druid, lambda { |druid|
    joins(:preserved_object).where(preserved_objects: { druid: druid })
  }

  # ideally, there should be only one distinct parts_count value among a set of sibling
  # zip_parts.  if there's variation in the count, that implies the zip was remade, and that
  # the part count differed between the zip invocations (which may imply a zip implementation
  # change, bitrot in the Moab on storage being archived, or some other unknown cause of drift).
  # hopefully this happens rarely or not at all, but an example scenario would be:
  # 1) zips get lost from cloud provider, 2) druid is re-queued for replication, no cached
  # zips available, 3) multi-part zip is remade, number of parts is fewer than prior zip/push,
  # 4) metadata on some existing part rows is updated with new (smaller) count, zips are pushed,
  # but old rows for prior push still exist with old (higher) count.
  def child_parts_counts
    zip_parts.group(:parts_count).pluck(:parts_count, Arel.sql('count(zip_parts.id)'))
  end

  def all_parts_replicated?
    # the assumption is that all of the database part records are created at once,
    # initialized to 'unreplicated', as soon as the (possibly multi-part) zip file
    # has been created and completely written to disk.  see DruidVersionZip.
    zip_parts.count.positive? && zip_parts.all?(&:ok?)
  end

  def total_part_size
    zip_parts.sum(&:size)
  end
end
