# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ObjectsController, type: :request do
  let(:prefixed_druid) { 'druid:bj102hs9687' }
  let(:bare_druid) { 'bj102hs9687' }
  let(:content_md) { '<contentMetadata>yer stuff here</contentMetadata>' }

  before do
    allow(Honeybadger).to receive(:notify)
  end

  describe 'POST #content_diff' do
    context 'when object exists' do
      context 'when druid is prefixed' do
        it 'returns the Moab::FileInventoryDifference as xml' do
          post content_diff_object_url(id: prefixed_druid),
               params: { content_metadata: content_md }.to_json,
               headers: valid_auth_header.merge('Content-Type' => 'application/json')
          expect(response).to have_http_status(:ok)
          result = HappyMapper.parse(response.body) # HappyMapper used in moab-versioning for parsing xml
          expect(result.object_id).to eq 'bj102hs9687'
          expect(result.basis).to eq 'v3-contentMetadata-all'
        end
      end

      context 'when druid is bare' do
        it 'returns the Moab::FileInventoryDifference as xml' do
          post content_diff_object_url(id: bare_druid),
               params: { content_metadata: content_md }.to_json,
               headers: valid_auth_header.merge('Content-Type' => 'application/json')
          expect(response).to have_http_status(:ok)
          result = HappyMapper.parse(response.body) # HappyMapper used in moab-versioning for parsing xml
          expect(result.object_id).to eq 'bj102hs9687'
          expect(result.basis).to eq 'v3-contentMetadata-all'
        end
      end

      context 'when version specified' do
        it 'returns correct Moab::FileInventoryDifference data' do
          post content_diff_object_url(id: prefixed_druid),
               params: { content_metadata: content_md, version: '1' }.to_json,
               headers: valid_auth_header.merge('Content-Type' => 'application/json')
          expect(response).to have_http_status(:ok)
          result = HappyMapper.parse(response.body) # HappyMapper used in moab-versioning for parsing xml
          expect(result.object_id).to eq 'bj102hs9687'
          expect(result.basis).to eq 'v1-contentMetadata-all'
        end

        context 'when version is too high' do
          it 'returns 500 response code with details' do
            post content_diff_object_url(id: prefixed_druid),
                 params: { content_metadata: content_md, version: '666' }.to_json,
                 headers: valid_auth_header.merge('Content-Type' => 'application/json')
            expect(response).to have_http_status(:internal_server_error)
            expect(response.body).to eq '500 Unable to get content diff: Version ID 666 does not exist'
          end
        end

        context 'when version param is not digits only' do
          it 'returns 400 response code with details' do
            post content_diff_object_url(id: prefixed_druid),
                 params: { content_metadata: content_md, version: 'v3' }.to_json,
                 headers: valid_auth_header.merge('Content-Type' => 'application/json')
            expect(response).to have_http_status(:bad_request)
            expect(response.body).to eq '400 Bad Request: version parameter must be positive integer'
          end
        end
      end

      context 'when ArgumentError from MoabStorageService' do
        it 'returns 400 response code with details' do
          params = { content_metadata: content_md, subset: 'unrecognized' }.to_json
          post content_diff_object_url(id: prefixed_druid),
               params: params,
               headers: valid_auth_header.merge('Content-Type' => 'application/json')
          expect(response).to have_http_status(:bad_request)
          error_response = JSON.parse(response.body)['errors'].first
          expect(error_response['status']).to eq('bad_request')
          expect(error_response['detail']).to include('unrecognized isn\'t include enum') # sic
        end
      end

      context 'when MoabRuntimeError from MoabStorageService' do
        it 'returns 500 response code; body has additional information; notifies Honeybadger' do
          emsg = 'my error'
          allow(Stanford::StorageServices).to receive(:compare_cm_to_version)
            .with(content_md, bare_druid, 'all', nil)
            .and_raise(Moab::MoabRuntimeError, emsg)
          post content_diff_object_url(id: bare_druid),
               params: { content_metadata: content_md }.to_json,
               headers: valid_auth_header.merge('Content-Type' => 'application/json')
          expect(response).to have_http_status(:internal_server_error)
          expect(response.body).to eq '500 Unable to get content diff: my error'
          expect(Honeybadger).to have_received(:notify).with(Moab::MoabRuntimeError)
        end
      end
    end

    context 'when object does not exist' do
      it 'returns an empty Moab::FileInventoryDifference as xml' do
        post content_diff_object_url(id: 'druid:xx123yy9999'),
             params: { content_metadata: content_md }.to_json,
             headers: valid_auth_header.merge('Content-Type' => 'application/json')
        expect(response).to have_http_status(:ok)
        result = HappyMapper.parse(response.body) # HappyMapper used in moab-versioning for parsing xml
        expect(result.object_id).to eq 'xx123yy9999'
        expect(result.difference_count).to eq '0'
      end
    end

    context 'when no id param' do
      context 'when id param missing' do
        it 'Rails will raise error and do the right thing' do
          expect do
            post content_diff_object_url({}), headers: valid_auth_header.merge('Content-Type' => 'application/json')
          end.to raise_error(ActionController::UrlGenerationError)
        end
      end
    end

    context 'when druid invalid' do
      it 'returns 400 response' do
        post content_diff_object_url(id: 'foobar'),
             params: { content_metadata: content_md, subset: 'all' }.to_json,
             headers: valid_auth_header.merge('Content-Type' => 'application/json')
        expect(response).to have_http_status(:bad_request)
        error_response = JSON.parse(response.body)['errors'].first
        expect(error_response['status']).to eq('bad_request')
        expect(error_response['detail']).to include('does not match value: foobar, example: druid:bc123df4567')
      end
    end

    context 'when druid empty' do
      it 'returns 404 response' do
        post content_diff_object_url(id: ''),
             params: { content_metadata: content_md, subset: 'all' },
             headers: valid_auth_header.merge('Content-Type' => 'application/json')
        expect(response).to have_http_status(:not_found)
        error_response = JSON.parse(response.body)['errors'].first
        expect(error_response['status']).to eq('not_found')
        expect(error_response['detail']).to include("That request method and path combination isn't defined.")
      end
    end
  end
end
