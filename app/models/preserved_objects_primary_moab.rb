# frozen_string_literal: true

# thin join table to contain a primary CompleteMoab for each PreservedObject
#  if nothing else, this model class provides us a way to access timestamps for these records
class PreservedObjectsPrimaryMoab < ApplicationRecord
  belongs_to :preserved_object, inverse_of: :preserved_objects_primary_moab
  belongs_to :complete_moab, inverse_of: :preserved_objects_primary_moab

  validate :complete_moab_matches_preserved_object

  def complete_moab_matches_preserved_object
    err_msg = 'must match the preserved object associated with the complete moab'
    errors.add(:preserved_object, err_msg) unless complete_moab.preserved_object == preserved_object
  end
end
