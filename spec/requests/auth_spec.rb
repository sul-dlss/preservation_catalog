# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'auth' do
  let(:pres_obj) { create(:preserved_object) }
  let(:pres_obj_returned) { JSON.parse(pres_obj.to_json) }

  before do
    allow(Honeybadger).to receive(:notify)
    allow(Honeybadger).to receive(:context)
    allow(Rails.logger).to receive(:warn)
    pres_obj_returned.delete("id")
    pres_obj_returned.delete("preservation_policy_id")
  end

  context 'without a bearer token' do
    it 'rejects the request as Not Authorized' do
      get "/v1/objects/#{pres_obj.druid}", headers: {}
      expect(response.body).to eq '{"error":"Not Authorized"}'
      expect(response).to be_unauthorized
    end

    it 'notifies Honeybadger' do
      get "/v1/objects/#{pres_obj.druid}", headers: {}
      expect(Honeybadger).to have_received(:notify).with("no Authorization token was provided by 127.0.0.1")
    end

    it 'logs a warning' do
      get "/v1/objects/#{pres_obj.druid}", headers: {}
      expect(Rails.logger).to have_received(:warn).with("no Authorization token was provided by 127.0.0.1")
    end
  end

  context 'with an invalid bearer token' do
    it 'rejects the request as Not Authorized' do
      get "/v1/objects/#{pres_obj.druid}", headers: invalid_auth_header
      expect(response.body).to eq '{"error":"Not Authorized"}'
      expect(response).to be_unauthorized
    end

    it 'notifies Honeybadger' do
      get "/v1/objects/#{pres_obj.druid}", headers: invalid_auth_header
      expect(Honeybadger).to have_received(:notify).with(
        "error validating bearer token #{invalid_jwt_value} provided by 127.0.0.1: Signature verification raised"
      )
    end

    it 'logs a warning' do
      get "/v1/objects/#{pres_obj.druid}", headers: invalid_auth_header
      expect(Rails.logger).to have_received(:warn).with(
        "error validating bearer token #{invalid_jwt_value} provided by 127.0.0.1: Signature verification raised"
      )
    end
  end

  context 'with a bearer token' do
    it 'logs token and caller to honeybadger' do
      get "/v1/objects/#{pres_obj.druid}", headers: valid_auth_header
      expect(Honeybadger).not_to have_received(:notify)
      expect(Honeybadger).to have_received(:context).with(invoked_by: jwt_payload[:sub])
    end

    it 'responds with a 200 OK and the correct body' do
      get "/v1/objects/#{pres_obj.druid}", headers: valid_auth_header
      expect(response.body).to include(pres_obj_returned.to_json)
      expect(response).to have_http_status(:ok)
    end
  end

  context 'when requesting an unprotected route' do
    it 'lets the request through without checking a Bearer token' do
      get '/resque/overview'
      expect(response).to have_http_status(:ok)
    end
  end
end
