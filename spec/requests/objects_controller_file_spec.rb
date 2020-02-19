# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ObjectsController, type: :request do
  let(:prefixed_druid) { 'druid:bj102hs9687' }
  let(:bare_druid) { 'bj102hs9687' }

  describe 'GET #file' do
    context 'when object exists' do
      context 'when druid is prefixed' do
        it 'returns the requested file' do
          get file_object_url(id: prefixed_druid), params: { category: 'manifest', filepath: 'manifestInventory.xml' }, headers: valid_auth_header
          expect(response).to have_http_status(:ok)
          expect(response.body).to include 'md5'
        end
      end

      context 'when druid is bare' do
        it 'returns the requested file' do
          get file_object_url(id: bare_druid), params: { category: 'manifest', filepath: 'manifestInventory.xml' }, headers: valid_auth_header
          expect(response).to have_http_status(:ok)
          expect(response.body).to include 'md5'
        end
      end

      context 'when file is not present in Moab' do
        it 'returns 404 response code; body has additional information' do
          get file_object_url(id: prefixed_druid), params: { category: 'manifest', filepath: 'foobar' }, headers: valid_auth_header
          expect(response).to have_http_status(:not_found)
          expect(response.body).to eq '404 Not Found: manifest file foobar not found for bj102hs9687 - 3'
        end
      end

      context 'when version specified' do
        it 'retrieves the correct version of the file' do
          params = { category: 'manifest', filepath: 'manifestInventory.xml', version: '3' }
          get file_object_url(id: prefixed_druid), params: params, headers: valid_auth_header
          expect(response).to have_http_status(:ok)
          expect(response.body).to include 'size="7133"'
        end

        context 'when version is too high' do
          it 'returns 404 response code with details' do
            get file_object_url(id: prefixed_druid), params: { category: 'manifest', filepath: 'ignored', version: '666' }, headers: valid_auth_header
            expect(response).to have_http_status(:not_found)
            expect(response.body).to eq '404 Not Found: Version ID 666 does not exist'
          end
        end

        context 'when version param is not digits only' do
          it 'returns 400 response code with details' do
            params = { category: 'manifest', filepath: 'manifestInventory.xml', version: 'v3' }
            get file_object_url(id: prefixed_druid), params: params, headers: valid_auth_header
            expect(response).to have_http_status(:bad_request)
            expect(response.body).to eq '400 Bad Request: version parameter must be positive integer'
          end
        end
      end

      context 'when ArgumentError from MoabStorageService' do
        it 'returns 400 response code with details' do
          get file_object_url(id: prefixed_druid), params: { category: 'metadata' }, headers: valid_auth_header
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to eq '400 Bad Request: No filename provided to MoabStorageService.filepath for druid bj102hs9687'
        end
      end
    end

    context 'when object does not exist' do
      it 'returns 404 response code with "No storage object found"' do
        get file_object_url(id: 'druid:xx123yy9999'), params: { category: 'manifest', filepath: 'manifestInventory.xml' }, headers: valid_auth_header
        expect(response).to have_http_status(:not_found)
        expect(response.body).to eq '404 Not Found: No storage object found for xx123yy9999'
      end
    end

    context 'when no id param' do
      context 'when id param is empty' do
        it "returns 404 with 'Couldn't find PreservedObject'" do
          get file_object_url(id: ''), params: { category: 'manifest', filepath: 'manifestInventory.xml' }, headers: valid_auth_header
          expect(response).to have_http_status(:not_found)
          expect(response.body).to eq "404 Not Found: Couldn't find PreservedObject"
        end
      end

      context "when id param missing" do
        it 'Rails will raise error and do the right thing' do
          expect do
            get file_object_url({}), params: { category: 'manifest', filepath: 'manifestInventory.xml' }, headers: valid_auth_header
          end.to raise_error(ActionController::UrlGenerationError)
        end
      end
    end

    context 'when druid invalid' do
      it 'returns 404 response code with "Identifier has invalid suri syntax"' do
        get file_object_url(id: 'foobar'), params: { category: 'manifest', filepath: 'manifestInventory.xml' }, headers: valid_auth_header
        expect(response).to have_http_status(:not_found)
        expect(response.body).to eq '404 Not Found: Identifier has invalid suri syntax: foobar'
      end
    end
  end
end
