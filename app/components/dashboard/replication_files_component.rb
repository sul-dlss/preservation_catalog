# frozen_string_literal: true

module Dashboard
  # methods for dashboard pertaining to ReplicationFilesComponent
  class ReplicationFilesComponent < ViewComponent::Base
    attr_reader :dashboard_replication_service

    delegate :zip_parts_total_size, to: :dashboard_replication_service

    def initialize
      @dashboard_replication_service = Dashboard::ReplicationService.new
      super
    end
  end
end
