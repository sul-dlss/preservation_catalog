# frozen_string_literal: true

module Audit
  # Check filesystem based on catalog, updating database
  # @see Audit::CatalogToMoab
  class CatalogToMoabJob < ApplicationJob
    queue_as :c2m

    limits_concurrency to: 1, key: ->(job) { job.arguments.first }, duration: 1.hour, on_conflict: :discard

    # @param [MoabRecord] moab_record object to C2M check
    # @see Audit::CatalogToMoab#initialize
    def perform(moab_record)
      Audit::CatalogToMoab.new(moab_record).check_catalog_version
    end
  end
end
