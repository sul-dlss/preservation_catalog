# frozen_string_literal: true

require 'rails_helper'
RSpec.describe ObjectsController, type: :request do
  let(:pres_obj) { create(:preserved_object) }
  let(:pres_obj_returned) { JSON.parse(pres_obj.to_json) }

  before do
    pres_obj_returned.delete("id")
    pres_obj_returned.delete("preservation_policy_id")
  end

  describe 'GET #show' do
    context 'when object found' do
      it 'response contains the object when given prefixed druid' do
        get object_url("druid:#{pres_obj.druid}", format: :json), headers: valid_auth_header
        expect(response.body).to include(pres_obj_returned.to_json)
        expect(response).to have_http_status(:ok)
      end

      it 'response contains the object when given bare druid' do
        get object_url(pres_obj.druid, format: :json), headers: valid_auth_header
        expect(response.body).to include(pres_obj_returned.to_json)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when object not found' do
      it 'returns a 404 response code and informative body' do
        get object_url('druid:bc123df4567', format: :json), headers: valid_auth_header
        expect(response).to have_http_status(:not_found)
        expect(response.body).to eq "404 Not Found: Couldn't find PreservedObject"
      end
    end
  end
end
