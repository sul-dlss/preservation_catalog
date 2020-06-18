# frozen_string_literal: true

# thin join table to contain a primary CompleteMoab for each PreservedObject
class PreservedObjectPrimaryMoab < ApplicationRecord
  belongs_to :preserved_object, inverse_of: :preserved_objects_primary_moabs
  belongs_to :complete_moab, inverse_of: :preserved_objects_primary_moabs
end
