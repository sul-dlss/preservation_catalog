# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ObjectsController do
  let(:pres_obj) do
    create(:preserved_object, current_version: 3).tap do |preserved_object|
      create(:moab_record, preserved_object:, status:)
    end
  end

  let(:status) { 'ok' }

  describe 'GET #show' do
    context 'when object found' do
      let(:expected_response) do
        {
          druid: pres_obj.druid,
          current_version: pres_obj.current_version,
          ok_on_local_storage: true
        }.to_json
      end

      it 'response contains the object when given prefixed druid' do
        get object_url("druid:#{pres_obj.druid}", format: :json), headers: valid_auth_header
        expect(response.body).to include(expected_response)
        expect(response).to have_http_status(:ok)
      end

      it 'response contains the object when given bare druid' do
        get object_url(pres_obj.druid, format: :json), headers: valid_auth_header
        expect(response.body).to include(expected_response)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when object not found' do
      it 'returns a 404 response code and informative body' do
        get object_url('druid:bc123df4567', format: :json), headers: valid_auth_header
        expect(response).to have_http_status(:not_found)
        expect(response.body).to eq '404 Not Found: Couldn\'t find PreservedObject with [WHERE "preserved_objects"."druid" = $1]'
      end
    end

    context 'when object found but moab_record is in error state' do
      let(:status) { 'invalid_moab' }

      let(:expected_response) do
        {
          druid: pres_obj.druid,
          current_version: pres_obj.current_version,
          ok_on_local_storage: false
        }.to_json
      end

      it 'response contains the object with ok_on_local_storage false' do
        get object_url(pres_obj.druid, format: :json), headers: valid_auth_header
        expect(response.body).to include(expected_response)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
