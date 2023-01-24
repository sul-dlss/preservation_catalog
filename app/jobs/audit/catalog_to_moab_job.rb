# frozen_string_literal: true

module Audit
  # Check filesystem based on catalog, updating database
  # @see Audit::CatalogToMoab
  class CatalogToMoabJob < ApplicationJob
    queue_as :audit_catalog_to_moab

    before_enqueue do |job|
      raise ArgumentError, 'MoabRecord param required' unless job.arguments.first.is_a?(MoabRecord)
    end

    include UniqueJob

    # @param [MoabRecord] moab_record object to C2M check
    # @see Audit::CatalogToMoab#initialize
    def perform(moab_record)
      Audit::CatalogToMoab.new(moab_record).check_catalog_version
    end
  end
end
