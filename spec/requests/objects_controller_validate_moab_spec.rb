# frozen_string_literal: true

require 'rails_helper'
RSpec.describe ObjectsController, type: :request do
  let(:prefixed_druid) { 'druid:bj102hs9687' }
  let(:bare_druid) { 'bj102hs9687' }
  let(:post_headers) { valid_auth_header.merge('Content-Type' => 'application/json') }

  describe 'GET #validate_moab' do
    context 'when valid druid passed in' do
      before do
        allow(ValidateMoabJob).to receive(:perform_later).and_return(true)
      end

      it 'queues the job and response ok' do
        get validate_moab_object_url(prefixed_druid), headers: valid_auth_header
        expect(response).to have_http_status(:ok)
        expect(ValidateMoabJob).to have_received(:perform_later).with(bare_druid)
      end

      it 'queues the job and response ok when given a bare druid' do
        get validate_moab_object_url(bare_druid), headers: valid_auth_header
        expect(response).to have_http_status(:ok)
        expect(ValidateMoabJob).to have_received(:perform_later).with(bare_druid)
      end
    end

    context 'when bad parameter passed in' do
      it 'returns a 400 response code' do
        get validate_moab_object_url('not a druid'), headers: valid_auth_header
        expect(response).to have_http_status(:bad_request)
        expect(ValidateMoabJob).not_to receive(:perform_later)
      end
    end
  end
end
