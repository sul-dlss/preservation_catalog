# frozen_string_literal: true

module Dashboard
  # Minimal controller for displaying a PreservedObject
  class ObjectsController < BaseController
    before_action :set_preserved_object, only: [:show]
    before_action :set_zip_parts_info, only: [:show]

    def show; end

    def druid
      @druid ||= params[:druid].delete_prefix('druid:')
    end

    private

    def set_preserved_object
      @preserved_object = PreservedObject.find_by(druid:)
    end

    def set_zip_parts_info
      return if Rails.env.development?

      @zip_parts_info = Audit::ReplicationSupport.zip_part_debug_info(druid)
    end
  end
end
