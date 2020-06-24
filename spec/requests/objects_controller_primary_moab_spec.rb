# frozen_string_literal: true

require 'rails_helper'
RSpec.describe ObjectsController, type: :request do
  let(:primary_moab) do
    create(:complete_moab).tap { |cm| PreservedObjectsPrimaryMoab.create(complete_moab: cm, preserved_object: cm.preserved_object) }
  end
  let(:pres_obj) { primary_moab.preserved_object }

  describe 'GET #primary_moab_location' do
    context 'when object found' do
      it 'response contains the locaiton of primary moab of the given prefixed druid' do
        get primary_moab_location_object_url("druid:#{pres_obj.druid}"), headers: valid_auth_header
        expect(response.body).to eq(primary_moab.moab_storage_root.storage_location)
        expect(response).to have_http_status(:ok)
      end

      it 'response contains the location of the primary moab when given bare druid' do
        get primary_moab_location_object_url(pres_obj.druid), headers: valid_auth_header
        expect(response.body).to eq(primary_moab.moab_storage_root.storage_location)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when object not found' do
      it 'returns a 404 response code and informative body' do
        get primary_moab_location_object_url('druid:bc123df4567'), headers: valid_auth_header
        expect(response).to have_http_status(:not_found)
        expect(response.body).to include "404 Not Found: Couldn't find MoabStorageRoot"
      end
    end
  end
end
