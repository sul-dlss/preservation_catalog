# Metadata about an endpoint which stores zipped archives of version directories from Moab
# objects.
class ArchiveEndpoint < ApplicationRecord
  has_many :archive_preserved_copies, dependent: :restrict_with_exception
  has_and_belongs_to_many :preservation_policies

  # @note Hash values cannot be modified without migrating any associated persisted data.
  # @see [enum docs] http://api.rubyonrails.org/classes/ActiveRecord/Enum.html
  enum delivery_class: {
    S3WestDeliveryJob => 1,
    S3EastDeliveryJob => 2
  }

  validates :endpoint_name, presence: true, uniqueness: true
end
