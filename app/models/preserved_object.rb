class PreservedObject < ApplicationRecord
  has_many :preservation_copies
  validates :druid, presence: true, uniqueness: true
end
