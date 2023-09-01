# frozen_string_literal: true

require 'rails_helper'
RSpec.describe ObjectsController do
  let(:prefixed_druid) { 'druid:bj102hs9687' }
  let(:prefixed_druid2) { 'druid:bz514sm9647' }
  let(:bare_druid) { 'bj102hs9687' }
  let(:bare_druid2) { 'bz514sm9647' }
  let(:prefixed_missing_druid) { 'druid:xx123yy9999' }
  let(:bare_missing_druid) { 'xx123yy9999' }
  let(:post_headers) { valid_auth_header.merge('Content-Type' => 'application/json') }

  describe 'GET #checksum' do
    context 'when object found' do
      it 'response contains the object checksum when given a prefixed druid' do
        get checksum_object_url(prefixed_druid), headers: valid_auth_header
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
        get checksum_object_url(bare_druid), headers: valid_auth_header
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
        get checksum_object_url(prefixed_missing_druid), headers: valid_auth_header
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when bad parameter passed in' do
      it 'returns a 400 response code' do
        get checksum_object_url('not a druid'), headers: valid_auth_header
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
