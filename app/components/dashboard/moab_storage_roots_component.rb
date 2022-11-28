# frozen_string_literal: true

module Dashboard
  # methods for dashboard pertaining to MoabStorageRootsComponent
  class MoabStorageRootsComponent < ViewComponent::Base
    attr_reader :dashboard_catalog_service

    delegate :status_labels,
             :storage_root_info,
             :storage_root_totals,
             :storage_root_total_count,
             :storage_root_total_ok_count,
             :num_complete_moabs,
             to: :dashboard_catalog_service

    def initialize
      @dashboard_catalog_service = Dashboard::CatalogService.new
      super
    end
  end
end
