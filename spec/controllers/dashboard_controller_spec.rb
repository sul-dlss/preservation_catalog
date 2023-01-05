# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DashboardController do
  render_views

  describe 'GET #index' do
    before do
      get :index
    end

    it 'returns a success response with html content' do
      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq('text/html; charset=utf-8')
      expect(response.body).to match(/Preservation Dashboard/)
    end

    describe 'nav side bar' do
      it 'has turbo-frame for moab_storage_status path' do
        expect(response.body).to match(/<turbo-frame id="moab-status" src="#{dashboard_moab_storage_status_path}" loading="lazy">/)
      end

      it 'has turbo-frame for replication_status path' do
        expect(response.body).to match(/<turbo-frame id="replication-status" src="#{dashboard_replication_status_path}" loading="lazy">/)
      end

      it 'has turbo-frame for audit_status path' do
        expect(response.body).to match(/<turbo-frame id="audit-status" src="#{dashboard_audit_status_path}" loading="lazy">/)
      end
    end

    describe '_moab_information partial' do
      it 'renders _moab_information template' do
        expect(response).to render_template('dashboard/_moab_information')
        expect(response.body).to match(/are about the Moab on storage./)
      end

      it 'has turbo-frame for moab_record_versions path' do
        expect(response.body).to match(/<turbo-frame id="moab-record-versions" src="#{dashboard_moab_record_versions_path}" loading="lazy">/)
      end

      it 'has turbo-frame for moab_record_info path' do
        expect(response.body).to match(/<turbo-frame id="moab-record-info" src="#{dashboard_moab_record_info_path}" loading="lazy">/)
      end

      it 'has turbo-frame for storage_root_data path' do
        expect(response.body).to match(/<turbo-frame id="storage-root-data" src="#{dashboard_storage_root_data_path}" loading="lazy">/)
      end
    end

    describe '_replication_information partial' do
      it 'renders _replication_information template' do
        expect(response).to render_template('dashboard/_replication_information')
        expect(response.body).to match(/Version Zips - Replication Status Information/)
      end

      it 'has turbo-frame for replication_endpoints path' do
        expect(response.body).to match(/<turbo-frame id="replication-endpoints" src="#{dashboard_replication_endpoints_path}" loading="lazy">/)
      end

      it 'has turbo-frame for replicated_files path' do
        expect(response.body).to match(/<turbo-frame id="replicated-files" src="#{dashboard_replicated_files_path}" loading="lazy">/)
      end

      it 'has turbo-frame for replication_flow path' do
        expect(response.body).to match(/<turbo-frame id="replication-flow" src="#{dashboard_replication_flow_path}" loading="lazy">/)
      end

      it 'has turbo frame for zip_part_suffix_counts path' do
        expect(response.body).to match(/<turbo-frame id="zip-part-suffix-counts" src="#{dashboard_zip_part_suffix_counts_path}" loading="lazy">/)
      end
    end

    it 'renders _audit_info template' do
      expect(response).to render_template('dashboard/_audit_info')
    end
  end

  describe 'GET dashboard/moab_storage_status' do
    before do
      get :moab_storage_status
    end

    it 'returns a success response with html content' do
      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq('text/html; charset=utf-8')
    end

    it 'renders _moab_storage_status template' do
      expect(response).to render_template('dashboard/_moab_storage_status')
    end

    it 'renders Dashboard::MoabOnStorageStatusComponent' do
      expect(response.body).to match(/Moabs on Storage/)
      expect(response.body).to match(%r{Object / Version Counts})
      expect(response.body).to match(/MoabRecord Statuses/)
      expect(response.body).to match(/OK/)
    end
  end

  describe 'GET dashboard/moab_record_versions' do
    before do
      get :moab_record_versions
    end

    it 'returns a success response with html content' do
      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq('text/html; charset=utf-8')
    end

    it 'renders _moab_record_versions template' do
      expect(response).to render_template('dashboard/_moab_record_versions')
    end

    it 'renders MoabRecord version data' do
      expect(response.body).to match(/Counts and Version Information/)
      expect(response.body).to match(/highest version/) # table header
    end
  end

  describe 'GET dashboard/moab_record_info' do
    before do
      get :moab_record_info
    end

    it 'returns a success response with html content' do
      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq('text/html; charset=utf-8')
    end

    it 'renders _moab_record_info template' do
      expect(response).to render_template('dashboard/_moab_record_info')
    end

    it 'renders MoabRecord Information' do
      expect(response.body).to match(/MoabRecord Information/)
      expect(response.body).to match(/total size/) # table header
      expect(response.body).to match(/0/) # table data
    end
  end

  describe 'GET dashboard/storage_root_data' do
    before do
      create(:moab_storage_root)
      get :storage_root_data
    end

    it 'returns a success response with html content' do
      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq('text/html; charset=utf-8')
    end

    it 'renders _storage_root_data template' do
      expect(response).to render_template('dashboard/_storage_root_data')
    end

    it 'renders MoabStorageRoot data' do
      expect(response.body).to match(/MoabStorageRoot Information/)
      expect(response.body).to match(/storage location/) # table header
      expect(response.body).to match(MoabStorageRoot.first&.storage_location) # table data
      expect(response.body).to match(/Bytes/) # table data
    end
  end

  describe 'GET dashboard/replication_status' do
    before do
      create(:zip_endpoint)
      get :replication_status
    end

    it 'returns a success response with html content' do
      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq('text/html; charset=utf-8')
    end

    it 'renders _replication_status template' do
      expect(response).to render_template('dashboard/_replication_status')
    end

    it 'renders replication status data' do
      expect(response.body).to match(/Replication Zips/)
      expect(response.body).to match(/Endpoint/)
      expect(response.body).to match(/Redis queues/)
      expect(response.body).to match('OK') # data
    end
  end

  describe 'GET dashboard/replication_endpoints' do
    before do
      create(:zip_endpoint)
      get :replication_endpoints
    end

    it 'returns a success response with html content' do
      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq('text/html; charset=utf-8')
    end

    it 'renders _replication_endpoints template' do
      expect(response).to render_template('dashboard/_replication_endpoints')
    end

    it 'renders replication endpoints data' do
      expect(response.body).to match(/Endpoint Data/)
      expect(response.body).to match(/ActiveJob class for replication/) # table header
      expect(response.body).to match(/S3WestDeliveryJob/) # table data
    end
  end

  describe 'GET dashboard/replicated_files' do
    before do
      get :replicated_files
    end

    it 'returns a success response with html content' do
      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq('text/html; charset=utf-8')
    end

    it 'renders _replicated_files template' do
      expect(response).to render_template('dashboard/_replicated_files')
    end

    it 'renders replicated files data' do
      expect(response.body).to match(/Replication Files/)
      expect(response.body).to match(/Total ZipParts/) # table header
      expect(response.body).to match(/0/) # table data
    end
  end

  describe 'GET dashboard/zip_part_suffix_counts' do
    before do
      create(:zip_part)
      get :zip_part_suffix_counts
    end

    it 'returns a success response with html content' do
      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq('text/html; charset=utf-8')
    end

    it 'renders _zip_part_suffix_counts template' do
      expect(response).to render_template('dashboard/_zip_part_suffix_counts')
      expect(response.body).to match(/ZipPart suffix counts/)
      expect(response.body).to match(/.zip/)
    end

    it 'renders ZipPart suffixes data' do
      expect(response.body).to match(/ZipPart/)
      expect(response.body).to match(/suffix/) # table header
      expect(response.body).to match(/.zip/) # table content
    end
  end

  describe 'GET dashboard/audit_status' do
    before do
      get :audit_status
    end

    it 'returns a success response with html content' do
      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq('text/html; charset=utf-8')
    end

    it 'renders _audit_status template' do
      expect(response).to render_template('_audit_status')
    end

    it 'renders audit status data' do
      expect(response.body).to match(/Audit/)
      expect(response.body).to match(/Moab to Catalog/)
      expect(response.body).to match(/Catalog to Archive/)
      expect(response.body).to match(/Redis queues/)
      expect(response.body).to match('OK') # data
    end
  end

  describe 'GET dashboard/audit_info' do
    before do
      get :audit_info
    end

    it 'returns a success response with html content' do
      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq('text/html; charset=utf-8')
    end

    it 'renders _audit_info template' do
      expect(response).to render_template('dashboard/_audit_info')
    end

    it 'renders audit information data' do
      expect(response.body).to match(/Audit Information/)
      expect(response.body).to match(/objects with errors/) # table header
      expect(response.body).to match('<td class="text-end">0</td>') # table data
    end
  end
end
