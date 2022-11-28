# frozen_string_literal: true

module Dashboard
  # methods for dashboard pertaining to CompleteMoabsComponent
  class CompleteMoabsComponent < ViewComponent::Base
    attr_reader :dashboard_catalog_service

    delegate :status_labels,
             :num_preserved_objects,
             :complete_moab_total_size,
             :complete_moab_average_size,
             :complete_moab_status_counts,
             :num_expired_checksum_validation,
             to: :dashboard_catalog_service

    def initialize
      @dashboard_catalog_service = Dashboard::CatalogService.new
      super
    end
  end
end
