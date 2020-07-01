# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ObjectsController, type: :request do
  let(:pres_obj) { primary_moab.preserved_object }
  let(:primary_moab) do
    create(:complete_moab) do |cm|
      PreservedObjectsPrimaryMoab.create(complete_moab: cm, preserved_object: cm.preserved_object)
    end
  end

  describe 'GET #primary_moab_location' do
    context 'when preserved object found' do
      it 'response contains location of primary moab given prefixed druid' do
        get primary_moab_location_object_url("druid:#{pres_obj.druid}"), headers: valid_auth_header
        expect(response.body).to eq(primary_moab.moab_storage_root.storage_location)
        expect(response).to have_http_status(:ok)
      end

      it 'response contains location of primary moab given bare druid' do
        get primary_moab_location_object_url(pres_obj.druid), headers: valid_auth_header
        expect(response.body).to eq(primary_moab.moab_storage_root.storage_location)
        expect(response).to have_http_status(:ok)
      end

      context 'when robot_versioning_allowed is false' do
        before do
          primary_moab.preserved_object.update(robot_versioning_allowed: false)
        end

        it 'returns a 423 response code and informative body' do
          get primary_moab_location_object_url(pres_obj.druid), headers: valid_auth_header
          expect(response).to have_http_status(:locked)
          expect(response.body).to include 'Cannot retrieve primary moab location because versioning ' \
            "is locked for the preserved object with id #{pres_obj.druid}"
        end
      end
    end

    context 'when preserved object not found' do
      it 'returns a 404 response code and informative body' do
        get primary_moab_location_object_url('druid:bc123df4567'), headers: valid_auth_header
        expect(response).to have_http_status(:not_found)
        expect(response.body).to include "404 Not Found: Couldn't find PreservedObject"
      end
    end
  end
end
