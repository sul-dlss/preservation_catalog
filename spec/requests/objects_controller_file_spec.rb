# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ObjectsController, type: :request do
  let(:prefixed_druid) { 'druid:bj102hs9687' }
  let(:bare_druid) { 'bj102hs9687' }
  let(:pres_obj) { create(:preserved_object) }

  describe 'GET #file' do
    context 'when object exists' do
      context 'when druid is prefixed' do
        context 'when no version param specified' do
          context 'when file is present' do
            context 'when type is manifest' do
              it 'returns the requested file' do
                get file_object_url(id: prefixed_druid), params: { type: 'manifest', filepath: 'manifestInventory.xml' }
                expect(response).to have_http_status(:ok)
                expect(response.body).to include 'md5'
              end
            end

            context 'when type is metadata' do
              it 'returns the requested file' do
                get file_object_url(id: prefixed_druid), params: { type: 'metadata', filepath: 'events.xml' }
                expect(response).to have_http_status(:ok)
                expect(response.body).to include 'Add missing versionMetadata'
              end
            end

            context 'when type is content' do
              it 'returns the requested file' do
                get file_object_url(id: prefixed_druid), params: { type: 'content', filepath: 'eric-smith-dissertation.pdf' }
                expect(response).to have_http_status(:ok)
                expect(response.body).to include 'md5'
              end
            end
          end

          context 'when file is absent' do
            it 'returns 404 response code; body has additional information' do
              get file_object_url(id: prefixed_druid), params: { type: 'manifest', filepath: 'foobar' }
              expect(response).to have_http_status(:not_found)
              expect(response.body).to eq '404 Not Found: manifest file foobar not found for bj102hs9687 - 3'
            end
          end

          context 'when filepath param is absent' do
            it 'returns 400 response code with details' do
              get file_object_url(id: prefixed_druid), params: { type: 'metadata'  }
              expect(response).to have_http_status(:bad_request)
              expect(response.body).to eq '400 Bad Request: filepath param must be populated'
            end
          end

          context 'when type param is unrecognized' do
            it 'returns 400 response code with details' do
              get file_object_url(id: prefixed_druid), params: { type: 'foobar', filepath: 'ignored' }
              expect(response).to have_http_status(:bad_request)
              expect(response.body).to eq '400 Bad Request: type param must be one of manifest, metadata, content'
            end
          end

          context 'when type param is missing' do
            it 'returns 400 response code with details' do
              get file_object_url(id: prefixed_druid), params: { filepath: 'ignored' }
              expect(response).to have_http_status(:bad_request)
              expect(response.body).to eq '400 Bad Request: type param must be one of manifest, metadata, content'
            end
          end

          context 'when format supplied' do
            it 'give ArgumentError' do
              expect do
                get file_object_url(id: prefixed_druid), format: :js, params: { type: 'manifest', filepath: 'manifestInventory.xml' }
              end.to raise_error(ArgumentError)
            end
          end
        end

        context 'when version specified' do
          it 'retrieves the correct version of the file' do
            get file_object_url(id: prefixed_druid), params: { type: 'manifest', filepath: 'manifestInventory.xml', version: '3' }
            expect(response).to have_http_status(:ok)
            expect(response.body).to include 'size="7133"'
          end

          context 'when version param is not digits only' do
            it 'returns 400 response code with details' do
              get file_object_url(id: prefixed_druid), params: { type: 'manifest', filepath: 'ignored', version: 'a' }
              expect(response).to have_http_status(:bad_request)
              expect(response.body).to eq '400 Bad Request: version param must be a positive integer'
            end
          end
        end
      end

      context 'when druid is bare' do
        it 'returns the requested file' do
          get file_object_url(id: bare_druid), params: { type: 'manifest', filepath: 'manifestInventory.xml' }
          expect(response).to have_http_status(:ok)
          expect(response.body).to include 'md5'
        end
      end
    end

    context 'when object does not exist' do
      it 'returns 404 response code with "No storage object found"' do
        get file_object_url(id: 'druid:xx123yy9999'), params: { type: 'manifest', filepath: 'manifestInventory.xml' }
        expect(response).to have_http_status(:not_found)
        expect(response.body).to eq '404 Not Found: No storage object found for xx123yy9999'
      end
    end

    context 'when no id param' do
      context 'when id param is empty' do
        it "returns 404 with 'Couldn't find PreservedObject'" do
          get file_object_url(id: ''), params: { type: 'manifest', filepath: 'manifestInventory.xml' }
          expect(response).to have_http_status(:not_found)
          expect(response.body).to eq "404 Not Found: Couldn't find PreservedObject"
        end
      end

      context "when no id param" do
        it 'Rails will raise error and do the right thing' do
          expect do
            get file_object_url({}), params: { type: 'manifest', filepath: 'manifestInventory.xml' }
          end.to raise_error(ActionController::UrlGenerationError)
        end
      end
    end

    context 'when druid invalid' do
      it 'returns 404 response code with "Identifier has invalid suri syntax"' do
        get file_object_url(id: 'foobar'), params: { type: 'manifest', filepath: 'manifestInventory.xml' }
        expect(response).to have_http_status(:not_found)
        expect(response.body).to eq '404 Not Found: Identifier has invalid suri syntax: foobar'
      end
    end
  end
end
