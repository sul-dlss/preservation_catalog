# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::SearchController do
  let(:pres_obj) do
    create(:preserved_object, current_version: 3).tap do |preserved_object|
      create(:moab_record, preserved_object:, status:)
    end
  end

  let(:status) { 'ok' }

  describe 'POST #create' do
    context 'when the preserved object exists' do
      it 'redirects to the object show page' do
        post dashboard_search_index_path,
             params: { druid: pres_obj.druid }.to_json,
             headers: valid_auth_header.merge('Content-Type' => 'application/json')

        expect(response).to redirect_to(dashboard_object_path(druid: pres_obj.druid))
        expect(response).to have_http_status(:found)
      end
    end
  end
end
