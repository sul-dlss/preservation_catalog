# frozen_string_literal: true

module Dashboard
  # methods for dashboard pertaining to ZipPartsSuffixesComponent
  class ZipPartsSuffixesComponent < ViewComponent::Base
    attr_reader :dashboard_replication_service

    delegate :zip_part_suffixes, to: :dashboard_replication_service

    def initialize
      @dashboard_replication_service = Dashboard::ReplicationService.new
      super
    end
  end
end
