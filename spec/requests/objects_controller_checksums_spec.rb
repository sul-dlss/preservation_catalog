# frozen_string_literal: true

require 'rails_helper'
RSpec.describe ObjectsController, type: :request do
  let(:prefixed_druid) { 'druid:bj102hs9687' }
  let(:prefixed_druid2) { 'druid:bz514sm9647' }
  let(:bare_druid) { 'bj102hs9687' }
  let(:bare_druid2) { 'bz514sm9647' }
  let(:pres_obj) { create(:preserved_object) }

  describe 'GET #checksum' do
    context 'when object found' do
      it 'response contains the object checksum when given a prefixed druid' do
        get checksum_object_url prefixed_druid, format: :json
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
        get checksum_object_url bare_druid, format: :json
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
        get checksum_object_url 'druid:xx123yy9999', format: :json
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when bad parameter passed in' do
      it 'returns a 400 response code' do
        get checksum_object_url 'not a druid', format: :json
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'POST #checksums' do
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
          get checksums_objects_url, params: { druids: [prefixed_druid, prefixed_druid2, bare_druid], format: :json }
          expect(response).to have_http_status(:ok)
          expect(response.body).to eq(expected_response.to_json)
        end

        it 'POST json response contains one checksum for each unique, normalized druid (in alpha order by druid)' do
          post checksums_objects_url, params: { druids: [prefixed_druid, prefixed_druid2, bare_druid], format: :json }
          expect(response).to have_http_status(:ok)
          expect(response.body).to eq(expected_response.to_json)
        end
      end

      it 'csv response contains multiple object checksums, but still normalizes and de-dupes druids, and alpha sorts by druid' do
        post checksums_objects_url, params: { druids: [prefixed_druid, prefixed_druid2], format: :csv }
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
          post checksums_objects_url, params: { druids: [prefixed_druid, prefixed_druid2, bare_druid], format: :json, return_bare_druids: true }
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
          post checksums_objects_url, params: { druids: [prefixed_druid, prefixed_druid2], format: :csv, return_bare_druids: true }
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
      it 'returns a 404 response code' do
        post checksums_objects_url, params: { druids: [prefixed_druid, 'druid:xx123yy9999'], format: :json }
        expect(response).to have_http_status(:not_found)
      end

      it 'body has additional information from the exception if available' do
        post checksums_objects_url, params: { druids: [prefixed_druid, 'druid:xx123yy9999'], format: :json }
        expect(response.body).to eq '404 Not Found: No storage object found for xx123yy9999'
      end
    end

    context 'when no druids param' do
      context 'when param is empty' do
        it 'body has additional information from the exception if available' do
          post checksums_objects_url, params: { druids: [], format: :json }
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to eq '400 bad request: Identifier has invalid suri syntax:  nil or empty'
        end
      end

      context "when no param" do
        it 'body has additional information from the exception if available' do
          post checksums_objects_url, params: { format: :json }
          expect(response).to have_http_status(:bad_request)
          expect(response.body).to eq '400 bad request - druids param must be populated'
        end
      end
    end

    context 'when druid invalid' do
      it 'returns 400 response code' do
        post checksums_objects_url, params: { druids: [prefixed_druid, 'foobar'], format: :json }
        expect(response).to have_http_status(:bad_request)
        expect(response.body).to eq '400 bad request: Identifier has invalid suri syntax: foobar'
      end
    end

    context 'when unsupported response format' do
      it 'returns 406 response code' do
        post checksums_objects_url, params: { druids: [prefixed_druid], format: :xml }
        expect(response).to have_http_status(:not_acceptable)
      end
    end
  end
end
