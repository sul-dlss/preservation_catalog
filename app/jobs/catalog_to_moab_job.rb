# frozen_string_literal: true

# Check filesystem based on catalog, updating database
# @see Audit::CatalogToMoab
class CatalogToMoabJob < ApplicationJob
  queue_as :c2m

  before_enqueue do |job|
    raise ArgumentError, 'CompleteMoab param required' unless job.arguments.first.is_a?(CompleteMoab)
  end

  include UniqueJob

  # @param [CompleteMoab] complete_moab object to C2M check
  # @see Audit::CatalogToMoab#initialize
  def perform(complete_moab)
    Audit::CatalogToMoab.new(complete_moab).check_catalog_version
  end
end
