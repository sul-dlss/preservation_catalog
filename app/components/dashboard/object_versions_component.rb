# frozen_string_literal: true

module Dashboard
  # methods for dashboard pertaining to ObjectVersionsComponent
  class ObjectVersionsComponent < ViewComponent::Base
    attr_reader :dashboard_catalog_service

    delegate :num_preserved_objects,
             :num_object_versions_per_preserved_object,
             :preserved_object_highest_version,
             :average_version_per_preserved_object,
             :num_complete_moabs,
             :num_object_versions_per_complete_moab,
             :complete_moab_highest_version,
             :average_version_per_complete_moab,
             to: :dashboard_catalog_service

    def initialize
      @dashboard_catalog_service = Dashboard::CatalogService.new
      super
    end
  end
end
