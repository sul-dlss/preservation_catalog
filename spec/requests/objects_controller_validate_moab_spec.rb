# frozen_string_literal: true

require 'rails_helper'
RSpec.describe ObjectsController, type: :request do
  let(:prefixed_druid) { 'druid:bj102hs9687' }
  let(:bare_druid) { 'bj102hs9687' }
  let(:post_headers) { valid_auth_header.merge('Content-Type' => 'application/json') }

  describe 'GET #validate_moab' do
    context 'when valid druid passed in' do
      before do
        allow(ValidateMoabJob).to receive(:perform_later).and_return(ValidateMoabJob.new)
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

    context 'when the caller tries to enqueue the job for a valid druid that is already in the queue' do
      before do
        # the first attempt to enqueue is successful and returns an instance of the job class,
        # the second attempt fails and returns false (simulating an attempt to queue when the
        # same job is already waiting to be worked)
        allow(ValidateMoabJob).to receive(:perform_later).and_return(ValidateMoabJob.new, false)
      end

      it 'returns a 423 response code' do
        get validate_moab_object_url(bare_druid), headers: valid_auth_header
        # expect(ValidateMoabJob).to have_received(:perform_later).with(bare_druid)
        expect(response).to have_http_status(:ok)

        get validate_moab_object_url(prefixed_druid), headers: valid_auth_header
        # expect(ValidateMoabJob).to have_received(:perform_later).with(bare_druid)
        expect(response).to have_http_status(:locked)
        expect(response.body).to include("Failed to enqueue ValidateMoabJob for #{bare_druid}")
        expect(response.body).to include('The most likely cause is that the job was already enqueued')

        expect(ValidateMoabJob).to have_received(:perform_later).with(bare_druid).exactly(2).times
      end
    end
  end
end
