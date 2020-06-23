# frozen_string_literal: true

require 'rails_helper'
RSpec.describe ObjectsController, type: :request do
  let(:pres_obj) { create(:preserved_object) }
  let(:primary_moab) { create(:complete_moab) }

  describe 'GET #primary_moab' do
    context 'when object found' do
      before do
        allow(pres_obj.preserved_objects_primary_moab).to receive(:complete_moab).and_return(primary_moab)
      end

      it 'response contains the primary moab of the given prefixed druid' do
        get primary_moab_object_url("druid:#{pres_obj.druid}", format: :json), headers: valid_auth_header
        expect(response.body).to include(primary_moab.to_json)
        expect(response).to have_http_status(:ok)
      end

      it 'response contains the object when given bare druid' do
        get primary_moab_object_url(pres_obj.druid, format: :json), headers: valid_auth_header
        expect(response.body).to include(primary_moab.to_json)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when object not found' do
      it 'returns a 404 response code and informative body' do
        get primary_moab_object_url('druid:bc123df4567', format: :json), headers: valid_auth_header
        expect(response).to have_http_status(:not_found)
        expect(response.body).to eq "404 Not Found: Couldn't find PreservedObject"
      end
    end
  end
end
