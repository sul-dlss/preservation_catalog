class PreservationCopy < ApplicationRecord
  belongs_to :preserved_object
  belongs_to :endpoint
  validates :preserved_object, presence: true
  validates :endpoint, presence: true
end
