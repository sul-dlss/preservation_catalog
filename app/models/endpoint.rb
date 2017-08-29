##
# Metadata about a replication endpoint, including a unique human
# readable name, and the type of endpoint it is (e.g. :online, :archive).
class Endpoint < ApplicationRecord
  has_many :preservation_copies
  validates :endpoint_name, presence: true, uniqueness: true
  validates :endpoint_type, presence: true
end
