# frozen_string_literal: true

module Dashboard
  # methods for dashboard pertaining to ReplicationEndpointsComponent
  class ReplicationEndpointsComponent < ViewComponent::Base
    attr_reader :dashboard_replication_service, :dashboard_catalog_service

    delegate :endpoint_data, to: :dashboard_replication_service

    delegate :num_object_versions_per_preserved_object, to: :dashboard_catalog_service

    def initialize
      @dashboard_replication_service = Dashboard::ReplicationService.new
      @dashboard_catalog_service = Dashboard::CatalogService.new
      super
    end
  end
end
