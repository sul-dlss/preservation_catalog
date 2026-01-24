# frozen_string_literal: true

module Dashboard
  # Minimal search controller for dashboard druid search
  class SearchController < BaseController
    def create
      redirect_to dashboard_object_path(druid:)
    end

    private

    def druid
      params[:druid]
    end
  end
end
