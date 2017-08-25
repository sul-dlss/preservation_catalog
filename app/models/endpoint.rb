class Endpoint < ApplicationRecord
  has_many :preservation_copies
  validates :endpoint_name, presence: true, uniqueness: true
  validates :endpoint_type, presence: true

end
