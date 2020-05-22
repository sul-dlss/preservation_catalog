# frozen_string_literal: true

require 'rails_helper'
RSpec.describe ObjectsController, type: :request do
  let(:prefixed_druid) { 'druid:bj102hs9687' }
  let(:prefixed_druid2) { 'druid:bz514sm9647' }
  let(:bare_druid) { 'bj102hs9687' }
  let(:bare_druid2) { 'bz514sm9647' }
  let(:post_headers) { valid_auth_header.merge('Content-Type' => 'application/json') }

  describe 'GET #checksum' do
    context 'when object found' do
      it 'response contains the object checksum when given a prefixed druid' do
        get checksum_object_url(prefixed_druid, format: :json), headers: valid_auth_header
        expected_response = [
          { filename: 'eric-smith-dissertation.pdf',
            md5: 'aead2f6f734355c59af2d5b2689e4fb3',
            sha1: '22dc6464e25dc9a7d600b1de6e3848bf63970595',
            sha256: 'e49957d53fb2a46e3652f4d399bd14d019600cf496b98d11ebcdf2d10a8ffd2f',
            filesize: 1_000_217 },
          { filename: 'eric-smith-dissertation-augmented.pdf',
            md5: '93802f1a639bc9215c6336ff5575ee22',
            sha1: '32f7129a81830004f0360424525f066972865221',
            sha256: 'a67276820853ddd839ba614133f1acd7330ece13f1082315d40219bed10009de',
            filesize: 905_566 }
        ]
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq(expected_response.to_json)
      end

      it 'response contains the object checksum when given a bare druid' do
        get checksum_object_url(bare_druid, format: :json), headers: valid_auth_header
        expected_response = [
          { filename: 'eric-smith-dissertation.pdf',
            md5: 'aead2f6f734355c59af2d5b2689e4fb3',
            sha1: '22dc6464e25dc9a7d600b1de6e3848bf63970595',
            sha256: 'e49957d53fb2a46e3652f4d399bd14d019600cf496b98d11ebcdf2d10a8ffd2f',
            filesize: 1_000_217 },
          { filename: 'eric-smith-dissertation-augmented.pdf',
            md5: '93802f1a639bc9215c6336ff5575ee22',
            sha1: '32f7129a81830004f0360424525f066972865221',
            sha256: 'a67276820853ddd839ba614133f1acd7330ece13f1082315d40219bed10009de',
            filesize: 905_566 }
        ]
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq(expected_response.to_json)
      end
    end

    context 'when object not found' do
      it 'returns a 404 response code' do
        get checksum_object_url('druid:xx123yy9999', format: :json), headers: valid_auth_header
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when bad parameter passed in' do
      it 'returns a 400 response code' do
        get checksum_object_url('not a druid', format: :json), headers: valid_auth_header
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'GET/POST #checksums' do
    context 'when objects found' do
      context 'get or post allowed for multiple druids' do
        let(:expected_response) {
          [
            { "#{prefixed_druid}":
              [{ filename: 'eric-smith-dissertation.pdf',
                 md5: 'aead2f6f734355c59af2d5b2689e4fb3',
                 sha1: '22dc6464e25dc9a7d600b1de6e3848bf63970595',
                 sha256: 'e49957d53fb2a46e3652f4d399bd14d019600cf496b98d11ebcdf2d10a8ffd2f',
                 filesize: 1_000_217 },
               { filename: 'eric-smith-dissertation-augmented.pdf',
                 md5: '93802f1a639bc9215c6336ff5575ee22',
                 sha1: '32f7129a81830004f0360424525f066972865221',
                 sha256: 'a67276820853ddd839ba614133f1acd7330ece13f1082315d40219bed10009de',
                 filesize: 905_566 }] },
            { "#{prefixed_druid2}":
              [{  filename: 'SC1258_FUR_032a.jpg',
                  md5: '42e9d4c0a766f837e5a2f5610d9f258e',
                  sha1: '5bfc6052b0e458e0aa703a0a6853bb9c112e0695',
                  sha256: '1530df24086afefd71bf7e5b7e85bb350b6972c838bf6c87ddd5c556b800c802',
                  filesize: 167_784 }] }
          ]
        }

        it 'GET json response contains one checksum for each unique, normalized druid (in alpha order by druid)' do
          get checksums_objects_url, params: { druids: [prefixed_druid, prefixed_druid2, bare_druid], format: :json }, headers: valid_auth_header
          expect(response).to have_http_status(:ok)
          expect(response.body).to eq(expected_response.to_json)
        end

        it 'POST json response contains one checksum for each unique, normalized druid (in alpha order by druid)' do
          post checksums_objects_url, params: { druids: [prefixed_druid, prefixed_druid2, bare_druid], format: :json }.to_json, headers: post_headers
          expect(response).to have_http_status(:ok)
          expect(response.body).to eq(expected_response.to_json)
        end
      end

      it 'csv response contains multiple object checksums, but still normalizes and de-dupes druids, and alpha sorts by druid' do
        post checksums_objects_url, params: { druids: [prefixed_druid, prefixed_druid2], format: :csv }.to_json, headers: post_headers
        expected_response = CSV.generate do |csv|
          csv << [prefixed_druid, 'eric-smith-dissertation.pdf', 'aead2f6f734355c59af2d5b2689e4fb3',
                  '22dc6464e25dc9a7d600b1de6e3848bf63970595', 'e49957d53fb2a46e3652f4d399bd14d019600cf496b98d11ebcdf2d10a8ffd2f', '1000217']
          csv << [prefixed_druid, 'eric-smith-dissertation-augmented.pdf', '93802f1a639bc9215c6336ff5575ee22',
                  '32f7129a81830004f0360424525f066972865221', 'a67276820853ddd839ba614133f1acd7330ece13f1082315d40219bed10009de', '905566']
          csv << [prefixed_druid2, 'SC1258_FUR_032a.jpg', '42e9d4c0a766f837e5a2f5610d9f258e',
                  '5bfc6052b0e458e0aa703a0a6853bb9c112e0695', '1530df24086afefd71bf7e5b7e85bb350b6972c838bf6c87ddd5c556b800c802', '167784']
        end
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq(expected_response)
      end

      context 'when the caller asks for bare druids in the response' do
        it 'json response contains one checksum for each unique, normalized druid (in alpha order by druid)' do
          params = { druids: [prefixed_druid, prefixed_druid2, bare_druid], format: :json, return_bare_druids: 'true' }
          post checksums_objects_url, params: params.to_json, headers: post_headers

          expected_response = [
            { "#{bare_druid}":
              [{ filename: 'eric-smith-dissertation.pdf',
                 md5: 'aead2f6f734355c59af2d5b2689e4fb3',
                 sha1: '22dc6464e25dc9a7d600b1de6e3848bf63970595',
                 sha256: 'e49957d53fb2a46e3652f4d399bd14d019600cf496b98d11ebcdf2d10a8ffd2f',
                 filesize: 1_000_217 },
               { filename: 'eric-smith-dissertation-augmented.pdf',
                 md5: '93802f1a639bc9215c6336ff5575ee22',
                 sha1: '32f7129a81830004f0360424525f066972865221',
                 sha256: 'a67276820853ddd839ba614133f1acd7330ece13f1082315d40219bed10009de',
                 filesize: 905_566 }] },
            { "#{bare_druid2}":
              [{  filename: 'SC1258_FUR_032a.jpg',
                  md5: '42e9d4c0a766f837e5a2f5610d9f258e',
                  sha1: '5bfc6052b0e458e0aa703a0a6853bb9c112e0695',
                  sha256: '1530df24086afefd71bf7e5b7e85bb350b6972c838bf6c87ddd5c556b800c802',
                  filesize: 167_784 }] }
          ]
          expect(response).to have_http_status(:ok)
          expect(response.body).to eq(expected_response.to_json)
        end

        it 'csv response contains multiple object checksums, but still normalizes and de-dupes druids, and alpha sorts by druid' do
          params = { druids: [prefixed_druid, prefixed_druid2], format: :csv, return_bare_druids: 'true' }
          post checksums_objects_url, params: params.to_json, headers: post_headers
          expected_response = CSV.generate do |csv|
            csv << [bare_druid, 'eric-smith-dissertation.pdf', 'aead2f6f734355c59af2d5b2689e4fb3',
                    '22dc6464e25dc9a7d600b1de6e3848bf63970595', 'e49957d53fb2a46e3652f4d399bd14d019600cf496b98d11ebcdf2d10a8ffd2f', '1000217']
            csv << [bare_druid, 'eric-smith-dissertation-augmented.pdf', '93802f1a639bc9215c6336ff5575ee22',
                    '32f7129a81830004f0360424525f066972865221', 'a67276820853ddd839ba614133f1acd7330ece13f1082315d40219bed10009de', '905566']
            csv << [bare_druid2, 'SC1258_FUR_032a.jpg', '42e9d4c0a766f837e5a2f5610d9f258e',
                    '5bfc6052b0e458e0aa703a0a6853bb9c112e0695', '1530df24086afefd71bf7e5b7e85bb350b6972c838bf6c87ddd5c556b800c802', '167784']
          end
          expect(response).to have_http_status(:ok)
          expect(response.body).to eq(expected_response)
        end
      end
    end

    context 'when object not found' do
      it 'returns a 409 response code' do
        post checksums_objects_url, params: { druids: [prefixed_druid, 'druid:xx123yy9999'], format: :json }.to_json, headers: post_headers
        expect(response).to have_http_status(:conflict)
      end

      it 'body has additional information from the exception if available' do
        post checksums_objects_url, params: { druids: [prefixed_druid, 'druid:xx123yy9999'], format: :json }.to_json, headers: post_headers
        expect(response.body).to eq "409 Conflict - \nStorage object(s) not found for xx123yy9999"
      end
    end

    context 'when object throws any StandardError during processing' do
      before do
        allow(MoabStorageService).to receive(:retrieve_content_file_group).with(bare_druid).and_call_original
        allow(MoabStorageService).to receive(:retrieve_content_file_group).with(bare_druid2).and_raise(NoMethodError, 'I had a nil result')
        post checksums_objects_url, params: { druids: [bare_druid, bare_druid2], format: :json }.to_json, headers: post_headers
      end

      it 'returns a 409 response code' do
        expect(response).to have_http_status(:conflict)
      end

      it 'body has additional information from the exception if available' do
        expect(response.body).to eq "409 Conflict - \nProblems generating checksums for #{bare_druid2} (#<NoMethodError: I had a nil result>)"
      end

      it 'body has information about both missing and errored druids if available' do
        allow(MoabStorageService).to receive(:retrieve_content_file_group).with('xx123yy9999').and_call_original
        allow(MoabStorageService).to receive(:retrieve_content_file_group).with(bare_druid).and_raise(StandardError, 'I had a stderr')
        allow(MoabStorageService).to receive(:retrieve_content_file_group).with(bare_druid2).and_raise(NoMethodError, 'I had a nil result')
        post checksums_objects_url, params: { druids: ['xx123yy9999', bare_druid, bare_druid2], format: :json }.to_json, headers: post_headers
        expect(response.body).to match '409 Conflict -'
        expect(response.body).to include "\nStorage object(s) not found for xx123yy9999"
        expect(response.body).to include "\nProblems generating checksums for #{bare_druid} (#<StandardError: I had a stderr>)"
        expect(response.body).to include ", #{bare_druid2} (#<NoMethodError: I had a nil result>)"
      end
    end

    context 'when no druids param' do
      context 'when param is empty' do
        it 'body has additional information from the exception if available' do
          post checksums_objects_url, params: { druids: [], format: :json }.to_json, headers: post_headers
          expect(response).to have_http_status(:bad_request)
          error_response = JSON.parse(response.body)['errors'].first
          expect(error_response['detail']).to include('druids [] contains fewer than min items')
        end
      end

      context 'when no param' do
        it 'body has additional information from the exception if available' do
          post checksums_objects_url, params: { format: :json }.to_json, headers: post_headers
          expect(response).to have_http_status(:bad_request)
          error_response = JSON.parse(response.body)['errors'].first
          expect(error_response['detail']).to include('schema missing required parameters: druids')
        end
      end
    end

    context 'when druid invalid' do
      it 'returns 400 response code' do
        post checksums_objects_url, params: { druids: [prefixed_druid, 'foobar'], format: :json }.to_json, headers: post_headers
        expect(response).to have_http_status(:bad_request)
        error_response = JSON.parse(response.body)['errors'].first
        expect(error_response['detail']).to include('does not match value: foobar, example: druid:bc123df4567')
      end
    end

    context 'when unsupported response format' do
      it 'returns 406 response code' do
        post checksums_objects_url, params: { druids: [prefixed_druid], format: :xml }.to_json, headers: post_headers
        expect(response).to have_http_status(:not_acceptable)
      end
    end
  end
end
