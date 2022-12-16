# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'routes' do
  let(:id) { 'druid:ab123cd4567' }

  describe 'objects/:id' do
    it 'object_path' do
      expect(get: object_path(id: id)).to route_to(controller: 'objects', action: 'show', id: id)
    end
  end

  describe 'objects/:id/file' do
    it 'file_object_path' do
      expect(get: file_object_path(id: id)).to route_to(controller: 'objects', action: 'file', id: id)
    end
  end

  describe 'objects/:id/checksum' do
    it 'checksum_object_path' do
      expect(get: checksum_object_path(id: id)).to route_to(controller: 'objects', action: 'checksum', id: id)
    end
  end

  describe 'objects/checksums' do
    it 'GET checksums_objects_path' do
      expect(get: checksums_objects_path).to route_to(controller: 'objects', action: 'checksums')
    end

    it 'POST checksums_objects_path' do
      expect(post: checksums_objects_path).to route_to(controller: 'objects', action: 'checksums')
    end
  end

  describe 'objects/:id/content_diff' do
    it 'content_diff_object_path' do
      expect(post: content_diff_object_path(id: id)).to route_to(controller: 'objects', action: 'content_diff', id: id)
    end
  end

  describe 'dashboard' do
    it 'routes to dashboard controller index action' do
      expect(get: dashboard_path).to route_to(controller: 'dashboard', action: 'index', format: 'html')
    end
  end

  describe 'dashboard/moab_storage_status' do
    it 'routes to dashboard controller moab_storage_status action' do
      expect(get: dashboard_moab_storage_status_path).to route_to(controller: 'dashboard', action: 'moab_storage_status', format: 'html')
    end
  end

  describe 'dashboard/moab_record_versions' do
    it 'routes to dashboard controller moab_record_versions action' do
      expect(get: dashboard_moab_record_versions_path).to route_to(controller: 'dashboard', action: 'moab_record_versions', format: 'html')
    end
  end

  describe 'dashboard/moab_record_info' do
    it 'routes to dashboard controller moab_record_info action' do
      expect(get: dashboard_moab_record_info_path).to route_to(controller: 'dashboard', action: 'moab_record_info', format: 'html')
    end
  end

  describe 'dashboard/storage_root_data' do
    it 'routes to dashboard controller storage_root_data action' do
      expect(get: dashboard_storage_root_data_path).to route_to(controller: 'dashboard', action: 'storage_root_data', format: 'html')
    end
  end

  describe 'dashboard/replication_status' do
    it 'routes to dashboard controller replication_status action' do
      expect(get: dashboard_replication_status_path).to route_to(controller: 'dashboard', action: 'replication_status', format: 'html')
    end
  end

  describe 'dashboard/replication_endpoints' do
    it 'routes to dashboard controller replication_endpoints action' do
      expect(get: dashboard_replication_endpoints_path).to route_to(controller: 'dashboard', action: 'replication_endpoints', format: 'html')
    end
  end

  describe 'dashboard/replication_flow' do
    it 'routes to dashboard controller replication_flow action' do
      expect(get: dashboard_replication_flow_path).to route_to(controller: 'dashboard', action: 'replication_flow', format: 'html')
    end
  end

  describe 'dashboard/replicated_files' do
    it 'routes to dashboard controller replicated_files action' do
      expect(get: dashboard_replicated_files_path).to route_to(controller: 'dashboard', action: 'replicated_files', format: 'html')
    end
  end

  describe 'dashboard/zip_part_suffix_counts' do
    it 'routes to dashboard controller zip_part_suffix_counts action' do
      expect(get: dashboard_zip_part_suffix_counts_path).to route_to(controller: 'dashboard', action: 'zip_part_suffix_counts', format: 'html')
    end
  end

  describe 'dashboard/audit_status' do
    it 'routes to dashboard controller audit_status action' do
      expect(get: dashboard_audit_status_path).to route_to(controller: 'dashboard', action: 'audit_status', format: 'html')
    end
  end

  describe 'dashboard/audit_info' do
    it 'routes to dashboard controller audit_info action' do
      expect(get: dashboard_audit_info_path).to route_to(controller: 'dashboard', action: 'audit_info', format: 'html')
    end
  end
end
