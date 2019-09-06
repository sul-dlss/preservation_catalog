# frozen_string_literal: true

require 'rails_helper'
RSpec.describe ObjectsController, type: :controller do
  let(:prefixed_druid) { 'druid:bj102hs9687' }
  let(:bare_druid) { 'bj102hs9687' }
  let(:pres_obj) { create(:preserved_object) }

  describe 'GET #show' do
    it 'response contains the object when found' do
      get :show, params: { id: "druid:#{pres_obj.druid}", format: :json }
      expect(response.body).to include(pres_obj.to_json)
      expect(response).to have_http_status(:ok)
    end

    it 'returns a 404 response code when object not found' do
      get :show, params: { id: "druid:garbage", format: :json }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET #checksums' do
    it 'response contains the checksums when found' do
      get :checksum, params: { id: prefixed_druid, format: :json }
      expected_response = [
        { filename: 'eric-smith-dissertation.pdf',
          md5: 'aead2f6f734355c59af2d5b2689e4fb3',
          sha1: '22dc6464e25dc9a7d600b1de6e3848bf63970595',
          sha256: 'e49957d53fb2a46e3652f4d399bd14d019600cf496b98d11ebcdf2d10a8ffd2f',
          filesize: 1_000_217 },
        { filename: 'eric-smith-dissertation-augmented.pdf',
          md5: '93802f1a639bc9215c6336ff5575ee22',
          sha1: '32f7129a81830004f0360424525f066972865221',
          sha256: 'a67276820853ddd839ba614133f1acd7330ece13f1082315d40219bed10009de',
          filesize: 905_566 }
      ]
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq(expected_response.to_json)
    end

    it 'returns a 404 response code when object not found' do
      get :checksum, params: { id: "druid:xx123yy9999", format: :json }
      expect(response).to have_http_status(:not_found)
    end

    it 'returns a 500 response code when bad parameter passed in' do
      get :checksum, params: { id: "not a druid", format: :json }
      expect(response).to have_http_status(:internal_server_error)
    end
  end
end
