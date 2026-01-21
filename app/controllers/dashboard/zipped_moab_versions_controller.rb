# frozen_string_literal: true

module Dashboard
  # Controller for listing ZippedMoabVersions in the dashboard
  class ZippedMoabVersionsController < BaseController
    def index
      @results, @total_result = ZippedMoabVersion.zipped_moab_versions_by_zip_endpoint
    end

    def with_errors
      @zipped_moab_versions = ZippedMoabVersion.with_errors.eager_load(:preserved_object).order(:status_updated_at).page(params[:page])
    end

    def stuck
      @zipped_moab_versions = ZippedMoabVersion.stuck.eager_load(:preserved_object).order(:status_updated_at).page(params[:page])
    end
  end
end
