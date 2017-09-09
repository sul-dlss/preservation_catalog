##
# the current status of a preservation copy, e.g. all good, fixity check failed, etc
class Status < ApplicationRecord
  has_many :preservation_copies
  validates :status_text, presence: true
end
