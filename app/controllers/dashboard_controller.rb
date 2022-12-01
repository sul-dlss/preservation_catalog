# frozen_string_literal: true

# Minimal controller for dashboard
class DashboardController < ApplicationController
  def index; end

  def moab_storage_status
    render 'dashboard/_moab_storage_status'
  end

  def complete_moab_versions
    render 'dashboard/_complete_moab_versions'
  end

  def complete_moab_info
    render 'dashboard/_complete_moab_info'
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

  def replicated_files
    render 'dashboard/_replicated_files'
  end

  def zip_part_suffix_counts
    render 'dashboard/_zip_part_suffix_counts'
  end

  def audit_status
    render 'dashboard/_audit_status'
  end

  def audit_info
    render 'dashboard/_audit_info'
  end
end
