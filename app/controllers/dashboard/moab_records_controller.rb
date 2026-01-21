# frozen_string_literal: true

module Dashboard
  # Controller for listing MoabRecords in the dashboard
  class MoabRecordsController < BaseController
    def with_errors
      @moab_records = MoabRecord.with_errors.eager_load(:preserved_object).order(:updated_at).page(params[:page])
    end

    def stuck
      @moab_records = MoabRecord.stuck.eager_load(:preserved_object).order(:updated_at).page(params[:page])
    end
  end
end
