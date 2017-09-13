##
# metadata about a specific replication endpoint
class EndpointType < ApplicationRecord
  has_many :endpoints

  validates :type_name, presence: true, uniqueness: true
  validates :endpoint_class, presence: true
end
