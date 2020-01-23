# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CatalogController, type: :request do
  let(:druid) { 'druid:bj102hs9687' }

  describe 'POST /catalog' do
    it 'redirects to /v1/catalog' do
      post '/catalog', headers: valid_auth_header
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(catalog_index_url)
    end
  end

  describe 'PUT /catalog/:druid' do
    it 'redirects to /v1/catalog/:druid' do
      put "/catalog/#{druid}", headers: valid_auth_header
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(catalog_url(druid))
    end
  end

  describe 'PATCH /catalog/:druid' do
    it 'redirects to /v1/catalog/:druid' do
      patch "/catalog/#{druid}", headers: valid_auth_header
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(catalog_url(druid))
    end
  end
end
