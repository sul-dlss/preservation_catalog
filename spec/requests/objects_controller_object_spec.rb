# frozen_string_literal: true

require 'rails_helper'
RSpec.describe ObjectsController, type: :request do
  let(:prefixed_druid) { 'druid:bj102hs9687' }
  let(:prefixed_druid2) { 'druid:bz514sm9647' }
  let(:bare_druid) { 'bj102hs9687' }
  let(:bare_druid2) { 'bz514sm9647' }
  let(:pres_obj) { create(:preserved_object) }

  describe 'GET #show' do
    context 'when object found' do
      it 'response contains the object when given prefixed druid' do
        get object_url "druid:#{pres_obj.druid}", format: :json
        expect(response.body).to include(pres_obj.to_json)
        expect(response).to have_http_status(:ok)
      end

      it 'response contains the object when given bare druid' do
        get object_url pres_obj.druid, format: :json
        expect(response.body).to include(pres_obj.to_json)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when object not found' do
      it 'returns a 404 response code' do
        get object_url 'druid:garbage', format: :json
        expect(response).to have_http_status(:not_found)
      end

      it 'returns useful info in the body' do
        get object_url 'druid:garbage', format: :json
        expect(response.body).to eq "404 Not Found: Couldn't find PreservedObject"
      end
    end
  end
end
