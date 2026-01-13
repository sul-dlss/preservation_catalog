# frozen_string_literal: true

# Minimal controller for dashboard
class DashboardController < ApplicationController
  def index; end

  def moab_storage_status
    render 'dashboard/_moab_storage_status'
  end

  def moab_record_versions
    render 'dashboard/_moab_record_versions'
  end

  def moab_record_info
    render 'dashboard/_moab_record_info'
  end

  def storage_root_data
    render 'dashboard/_storage_root_data'
  end

  def replication_status
    render 'dashboard/_replication_status'
  end

  def replication_endpoints
    render 'dashboard/_replication_endpoints'
  end

  def zipped_moab_version_status
    render 'dashboard/_zipped_moab_version_status'
  end

  def audit_status
    render 'dashboard/_audit_status'
  end

  def audit_info
    render 'dashboard/_audit_info'
  end
end
