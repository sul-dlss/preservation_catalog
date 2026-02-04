# frozen_string_literal: true

module Dashboard
  # Minimal controller for displaying a PreservedObject
  class ObjectsController < BaseController
    before_action :set_preserved_object

    def show; end

    def checksum_validation
      @preserved_object.moab_record.validate_checksums!

      flash[:notice] = "Checksum validation job started for #{@druid}."
      redirect_to dashboard_object_path(@druid)
    end

    def replication_audit
      @preserved_object.audit_moab_version_replication!

      flash[:notice] = "Replication audit job started for #{@druid}."
      redirect_to dashboard_object_path(@druid)
    end

    private

    def set_preserved_object
      @druid = params[:druid].delete_prefix('druid:')
      @preserved_object = PreservedObject.find_by(druid: @druid)
    end
  end
end
