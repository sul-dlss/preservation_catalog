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

    describe 'nav bar' do
      it 'renders _catalog_status template' do
        expect(response).to render_template('dashboard/_catalog_status')
        expect(response.body).to match(/Catalog Status/)
      end

      it 'renders _audit_status template' do
        expect(response).to render_template('dashboard/_audit_status')
        expect(response.body).to match(/Audit Status/)
      end

      it 'renders _replication_status template' do
        expect(response).to render_template('dashboard/_replication_status')
        expect(response.body).to match(/Replication Status/)
      end
    end

    describe 'catalog information' do
      it 'renders _catalog_information template' do
        expect(response).to render_template('dashboard/_catalog_information')
        expect(response.body).to match(/Catalog Status Information/)
      end

      it 'renders object version data' do
        expect(response.body).to match(/Counts and Version Information/)
        expect(response.body).to match(/highest version/) # table header
      end

      it 'renders CompletMoab data' do
        expect(response.body).to match(/CompleteMoab Information/)
        expect(response.body).to match(/total size/) # table header
        expect(response.body).to match(/TB/)
      end

      it 'renders MoabStorageRoot data' do
        expect(response.body).to match(/MoabStorageRoot Information/)
        expect(response.body).to match(/storage location/) # table header
        expect(response.body).to match(MoabStorageRoot.first.storage_location) # table data
        expect(response.body).to match(/Bytes/) # table data
      end
    end

    describe 'replication information' do
      it 'renders _replication_information template' do
        expect(response).to render_template('dashboard/_replication_information')
        expect(response.body).to match(/S3 Replication Information/)
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
