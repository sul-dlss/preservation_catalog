# frozen_string_literal: true

module Dashboard
  # Minimal controller for displaying a PreservedObject
  class ObjectsController < BaseController
    def show
      @druid = params[:druid].delete_prefix('druid:')
      @preserved_object = PreservedObject.find_by(druid: @druid)
    end
  end
end
