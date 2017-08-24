class PreservationCopy < ApplicationRecord
  belongs_to :preserved_object
  belongs_to :endpoint
end
