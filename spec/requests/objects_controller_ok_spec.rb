# frozen_string_literal: true

require 'rails_helper'
RSpec.describe ObjectsController do
  let(:preserved_object) do
    create(:preserved_object).tap do |preserved_object|
      create(:moab_record, preserved_object:, status:)
    end
  end

  let(:status) { 'ok' }

  describe 'GET #ok' do
    context 'when object is ok' do
      it 'returns true' do
        get ok_object_url("druid:#{preserved_object.druid}"), headers: valid_auth_header
        expect(JSON.parse(response.body)).to be true
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when object is not ok' do
      let(:status) { 'invalid_moab' }

      it 'returns false' do
        get ok_object_url(preserved_object.druid), headers: valid_auth_header
        expect(JSON.parse(response.body)).to be false
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when object not found' do
      it 'returns a 404' do
        get ok_object_url('druid:bc123df4567'), headers: valid_auth_header
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
