# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dashboard' do
  describe 'GET #index' do
    before do
      get dashboard_url
    end

    it 'returns a success response with html content' do
      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq('text/html; charset=utf-8')
      expect(response.body).to match(/Preservation Dashboard/)
    end

    describe 'nav side bar' do
      it 'renders Dashboard::MoabOnStorageStatusComponent' do
        expect(response.body).to match(/Moabs on Storage/)
        expect(response.body).to match(%r{Object / Version Counts})
        expect(response.body).to match(/CompleteMoab Statuses/)
        expect(response.body).to match(/OK/)
      end

      it 'renders Dashboard::ReplicationStatusComponent' do
        expect(response.body).to match(/Replication Zips/)
        expect(response.body).to match(/Endpoint/)
        expect(response.body).to match(/Redis queues/)
      end

      it 'renders Dashboard::AuditStatusComponent' do
        expect(response.body).to match(/Audit/)
        expect(response.body).to match(/Catalog to Moab/)
        expect(response.body).to match(/Catalog to Archive/)
      end
    end

    describe 'moabs on storage information' do
      it 'renders _moab_information template' do
        expect(response).to render_template('dashboard/_moab_information')
        expect(response.body).to match(/Moabs on Storage - Status Information/)
      end

      it 'renders object version data' do
        expect(response.body).to match(/Counts and Version Information/)
        expect(response.body).to match(/highest version/) # table header
      end

      it 'renders CompleteMoab data' do
        expect(response.body).to match(/CompleteMoab Information/)
        expect(response.body).to match(/total size/) # table header
        expect(response.body).to match(/0/) # table data
      end

      it 'renders MoabStorageRoot data' do
        expect(response.body).to match(/MoabStorageRoot Information/)
        expect(response.body).to match(/storage location/) # table header
        expect(response.body).to match(MoabStorageRoot.first.storage_location) # table data
        expect(response.body).to match(/Bytes/) # table data
      end
    end

    describe 'replication zip information' do
      it 'renders _replication_information template' do
        expect(response).to render_template('dashboard/_replication_information')
        expect(response.body).to match(/Version Zips - Replication Status Information/)
      end

      it 'renders replication endpoint data' do
        expect(response.body).to match(/Endpoint Data/)
        expect(response.body).to match(/ActiveJob class for replication/) # table header
        expect(response.body).to match(/S3WestDeliveryJob/) # table data
      end

      it 'renders replication files data' do
        expect(response.body).to match(/Replication Files/)
        expect(response.body).to match(/Total ZipParts/) # table header
      end

      it 'renders _replication_flow template' do
        expect(response).to render_template('dashboard/_replication_flow')
        expect(response.body).to match(/Replication Flow/)
        # all content is static, so no need to check for specific content
      end

      it 'renders ZipPart suffixes data' do
        expect(response.body).to match(/ZipPart/)
        expect(response.body).to match(/suffix/) # table header
        expect(response.body).to match(/.zip/) # table content
      end
    end

    describe 'audit information' do
      it 'renders audit information data' do
        expect(response.body).to match(/Audit Information/)
        expect(response.body).to match(/objects with errors/) # table header
        expect(response.body).to match('<td>0</td>') # table data
      end
    end
  end
end
