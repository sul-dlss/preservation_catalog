# frozen_string_literal: true

require 'rails_helper'
RSpec.describe CatalogController, type: :controller do
  let(:audit_workflow_reporter) { instance_double(Reporters::AuditWorkflowReporter, report_errors: nil) }
  let(:size) { 2342 }
  let(:ver) { 3 }
  let(:bare_druid) { 'bj102hs9687' }
  let(:prefixed_druid) { "druid:#{bare_druid}" }
  let(:storage_location) { "#{storage_location_param}/sdr2objects" }
  let(:storage_location_param) { 'spec/fixtures/storage_root01' }
  let(:event_service_reporter) { instance_double(Reporters::EventServiceReporter, report_errors: nil) }
  let(:honeybadger_reporter) { instance_double(Reporters::HoneybadgerReporter, report_errors: nil) }
  let(:logger_reporter) { instance_double(Reporters::LoggerReporter, report_errors: nil) }

  before do
    allow(described_class.logger).to receive(:info) # silence STDOUT chatter
    allow(Reporters::AuditWorkflowReporter).to receive(:new).and_return(audit_workflow_reporter)
    allow(Reporters::EventServiceReporter).to receive(:new).and_return(event_service_reporter)
    allow(Reporters::HoneybadgerReporter).to receive(:new).and_return(honeybadger_reporter)
    allow(Reporters::LoggerReporter).to receive(:new).and_return(logger_reporter)
    allow(controller).to receive(:check_auth_token!) # gating on valid token tested in request specs and auth spec
  end

  describe 'POST #create' do
    context 'with valid params' do
      let(:pres_obj) { PreservedObject.find_by(druid: bare_druid) }
      let(:comp_moab) { CompleteMoab.find_by(preserved_object: pres_obj) }

      before do
        post :create, params: { druid: prefixed_druid, incoming_version: ver, incoming_size: size, storage_location: storage_location_param }
      end

      it 'saves PreservedObject and CompleteMoab in db' do
        po = PreservedObject.find_by(druid: bare_druid)
        cm = CompleteMoab.find_by(preserved_object: po)
        expect(po).to be_an_instance_of PreservedObject
        expect(cm).to be_an_instance_of CompleteMoab
      end

      it 'CompleteMoab and PreservedObject have correct attributes' do
        expect(comp_moab.moab_storage_root.storage_location).to eq storage_location
        expect(comp_moab.version).to eq ver
        expect(comp_moab.size).to eq size
        expect(pres_obj.druid).to eq bare_druid
      end

      it 'response contains create_new_object code ' do
        exp_msg = [{ AuditResults::CREATED_NEW_OBJECT => 'added object to db as it did not exist' }]
        expect(response.body).to include(exp_msg.to_json)
      end

      it 'returns a created response code' do
        expect(response).to have_http_status(:created)
      end
    end

    context 'with invalid params' do
      before do
        post :create, params: { druid: nil, incoming_version: ver, incoming_size: size, storage_location: storage_location_param }
      end

      it 'does not save PreservedObject or CompleteMoab in db' do
        po = PreservedObject.find_by(druid: prefixed_druid)
        cm = CompleteMoab.find_by(preserved_object: po)
        expect(po).to be_nil
        expect(cm).to be_nil
      end

      it 'response contains error message' do
        errors = ["Druid can't be blank", 'Druid is invalid']
        exp_msg = [{ AuditResults::INVALID_ARGUMENTS => "encountered validation error(s): #{errors}" }]
        expect(response.body).to include(exp_msg.to_json)
      end

      it 'returns a not acceptable response code' do
        expect(response).to have_http_status(:not_acceptable)
      end
    end

    context 'object already exists' do
      before do
        post :create, params: { druid: prefixed_druid, incoming_version: ver, incoming_size: size, storage_location: storage_location_param }
        post :create, params: { druid: prefixed_druid, incoming_version: ver, incoming_size: size, storage_location: storage_location_param }
      end

      it 'response contains error message' do
        exp_msg = [{ AuditResults::DB_OBJ_ALREADY_EXISTS => 'CompleteMoab db object already exists' }]
        expect(response.body).to include(exp_msg.to_json)
      end

      it 'returns a conflict response code' do
        expect(response).to have_http_status(:conflict)
      end
    end

    context 'db update failed' do
      before do
        allow(PreservedObject).to receive(:create!).with(hash_including(druid: bare_druid))
                                                   .and_raise(ActiveRecord::ActiveRecordError, 'foo')
        post :create, params: { druid: prefixed_druid, incoming_version: ver, incoming_size: size, storage_location: storage_location_param }
      end

      it 'response contains error message' do
        code = AuditResults::DB_UPDATE_FAILED.to_json
        expect(response.body).to include(code)
      end

      it 'returns an internal server error response code' do
        expect(response).to have_http_status(:internal_server_error)
      end
    end

    it 'response body contains druid' do
      post :create, params: { druid: prefixed_druid, incoming_version: ver, incoming_size: size, storage_location: storage_location_param }
      expect(response.body).to include(bare_druid)
    end

    context "can take druid with or without 'druid:' prefix " do
      let(:bare_druid) { 'jj925bx9565' }
      let(:prefixed_druid) { "druid:#{bare_druid}" }

      it 'prefixed_druid' do
        post :create, params: { druid: prefixed_druid, incoming_version: ver, incoming_size: size, storage_location: storage_location_param }
        expect(response.body).to include(bare_druid)
        expect(response.body).not_to include(prefixed_druid)
        expect(response).to have_http_status(:created)
      end

      it 'bare druid' do
        post :create, params: { druid: bare_druid, incoming_version: ver, incoming_size: size, storage_location: storage_location_param }
        expect(response.body).to include(bare_druid)
        expect(response.body).not_to include(prefixed_druid)
        expect(response).to have_http_status(:created)
      end
    end
  end

  describe 'PATCH #update' do
    let(:bare_druid) { 'bz514sm9647' }
    let!(:pres_obj) do
      # creates a PreservedObject, and the CompleteMoab for the first moab found for the druid (by walking the storage roots in configured order)
      create(:preserved_object_fixture, druid: bare_druid)
    end
    let(:comp_moab) do
      pres_obj.complete_moabs.find_by!(moab_storage_root: MoabStorageRoot.find_by!(name: 'fixture_sr1'))
    end
    let!(:comp_moab_sr_a) do
      # create a CompleteMoab record for the other moab we have for this druid, to confirm support for multiple copies of a moab
      create(:complete_moab, preserved_object: pres_obj, version: 1, moab_storage_root: MoabStorageRoot.find_by!(name: 'fixture_srA'))
    end
    let(:primary_moab) { comp_moab }

    before do
      PreservedObjectsPrimaryMoab.create!(preserved_object: pres_obj, complete_moab: primary_moab)
    end

    context 'with valid params' do
      before do
        patch :update, params: { druid: prefixed_druid, incoming_version: upd_version, incoming_size: size, storage_location: storage_location_param }
      end

      let(:upd_version) { 4 }

      it 'updates CompleteMoab#version' do
        expect(comp_moab.reload.version).to eq upd_version
      end

      it 'updates PreservedObject#current_version' do
        expect(pres_obj.reload.current_version).to eq upd_version
      end

      it 'returns an ok response code' do
        expect(response).to have_http_status(:ok)
      end

      context 'updating a non-primary' do
        let!(:pres_obj) { create(:preserved_object, druid: bare_druid, current_version: 1) } # as if the one on srA was always primary
        let!(:comp_moab) { create(:complete_moab, preserved_object: pres_obj, version: 3) } # create fixture_sr1 record, not created w/ PO this case
        let(:primary_moab) { comp_moab_sr_a } # but we're still doing PATCH on the fixture_sr1 moab

        it 'updates CompleteMoab#version' do
          pending('this is known to fail, because CMH does not update CompleteMoab if its version does not match parent PO#current_version')
          expect(comp_moab.reload.version).to eq upd_version
        end

        it 'updates PreservedObject#current_version' do
          expect(pres_obj.reload.current_version).to eq primary_moab.version
        end
      end
    end

    context 'with invalid params' do
      before do
        patch :update, params: { druid: prefixed_druid, incoming_version: ver, incoming_size: size, storage_location: nil }
      end

      it 'response contains error message' do
        errors = ['Moab storage root must be an actual MoabStorageRoot']
        exp_msg = [{ AuditResults::INVALID_ARGUMENTS => "encountered validation error(s): #{errors}" }]
        expect(response.body).to include(exp_msg.to_json)
      end

      it 'returns a not acceptable response code' do
        expect(response).to have_http_status(:not_acceptable)
      end
    end

    context 'object does not exist' do
      before do
        patch :update, params: { druid: 'druid:rr111rr1111', incoming_version: ver, incoming_size: size, storage_location: storage_location_param }
      end

      it 'response contains error message' do
        err_regex = /#<ActiveRecord::RecordNotFound: Couldn't find (PreservedObject|CompleteMoab).*> db object does not exist/
        exp_result = { 'result_array' => [{ AuditResults::DB_OBJ_DOES_NOT_EXIST.to_s => a_string_matching(err_regex) }] }
        expect(JSON.parse(response.body)).to include(exp_result)
      end

      it 'returns a not found error' do
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'cm po version mismatch' do
      before do
        comp_moab.version = comp_moab.version + 1
        comp_moab.save!
        patch :update, params: { druid: prefixed_druid, incoming_version: ver, incoming_size: size, storage_location: storage_location_param }
      end

      it 'response contains error message' do
        exp_msg = [{ AuditResults::CM_PO_VERSION_MISMATCH => 'CompleteMoab online Moab version 4 does not match PreservedObject current_version 3' }]
        expect(response.body).to include(exp_msg.to_json)
      end

      it 'returns an internal server error' do
        expect(response).to have_http_status(:internal_server_error)
      end
    end

    context 'unexpected version' do
      before do
        patch :update, params: { druid: prefixed_druid, incoming_version: 1, incoming_size: size, storage_location: storage_location_param }
      end

      it 'response contains error message' do
        unexp_ver = 'actual version (1) has unexpected relationship to CompleteMoab db version (3); ERROR!'
        ver_lt_db = 'actual version (1) less than CompleteMoab db version (3); ERROR!'
        status_change = 'CompleteMoab status changed from validity_unknown to unexpected_version_on_storage'
        exp_msg = [
          { AuditResults::UNEXPECTED_VERSION => unexp_ver.to_s },
          { AuditResults::ACTUAL_VERS_LT_DB_OBJ => ver_lt_db.to_s },
          { AuditResults::CM_STATUS_CHANGED => status_change.to_s }
        ]
        expect(response.body).to include(exp_msg.to_json)
      end

      it 'returns an internal server error' do
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'db update transaction failed' do
      before do
        # pretend DB records are 1 version behind what's on disk, so update gets what it expects; we're testing
        # specifically for DB update failure bubbling up
        pres_obj.update(current_version: pres_obj.current_version - 1)
        comp_moab.update(version: comp_moab.version - 1)
        allow(CompleteMoab).to receive(:joins).and_raise(ActiveRecord::ActiveRecordError, 'connection error foo')
      end

      it 'response contains error message' do
        patch :update, params: { druid: prefixed_druid, incoming_version: ver, incoming_size: size, storage_location: storage_location_param }
        code = AuditResults::DB_UPDATE_FAILED.to_json
        expect(response.body).to include(code)
      end

      it 'returns an internal server error response code' do
        patch :update, params: { druid: prefixed_druid, incoming_version: ver, incoming_size: size, storage_location: storage_location_param }
        expect(response).to have_http_status(:internal_server_error)
      end
    end

    it 'response body contains druid' do
      post :update, params: { druid: prefixed_druid, incoming_version: ver, incoming_size: size, storage_location: storage_location_param }
      expect(response.body).to include(bare_druid)
    end

    context "can take druid with or without 'druid:' prefix " do
      before do
        post :create, params: { druid: prefixed_druid, incoming_version: ver, incoming_size: size, storage_location: storage_location_param }
      end

      let(:prefixed_druid) { "druid:#{bare_druid}" }
      let(:bare_druid) { 'jj925bx9565' }

      it 'prefixed_druid' do
        patch :update, params: { druid: prefixed_druid, incoming_version: 5, incoming_size: size, storage_location: storage_location_param }
        expect(response.body).to include(bare_druid)
        expect(response.body).not_to include(prefixed_druid)
        expect(response).to have_http_status(:ok)
      end

      it 'bare druid' do
        patch :update, params: { druid: bare_druid, incoming_version: 5, incoming_size: size, storage_location: storage_location_param }
        expect(response.body).to include(bare_druid)
        expect(response.body).not_to include(prefixed_druid)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'parameters' do
    describe 'checksums_validated' do
      let(:results) { instance_double(AuditResults) }
      let(:complete_moab_handler) { instance_double(CompleteMoabHandler) }

      before do
        allow(results).to receive(:contains_result_code?)
        allow(complete_moab_handler).to receive(:results).and_return(results)
        allow(CompleteMoabHandler).to receive(:new).and_return(complete_moab_handler)
      end

      it 'false if not present' do
        expect(complete_moab_handler).to receive(:create).with(false)
        post :create, params: { druid: bare_druid, incoming_version: ver, incoming_size: size, storage_location: storage_location_param }
      end

      ['true', 'True', 'TRUE'].each do |t_val|
        it "#{t_val} evaluates to true" do
          expect(complete_moab_handler).to receive(:create).with(true)
          post :create, params: { druid: bare_druid,
                                  incoming_version: ver,
                                  incoming_size: size,
                                  storage_location: storage_location_param,
                                  checksums_validated: t_val }
        end
      end
      ['nil', '1', 'on', 'false', 'False', 'FALSE'].each do |t_val|
        it "#{t_val} evaluates to false" do
          expect(complete_moab_handler).to receive(:update_version).with(false)
          patch :update, params: { druid: bare_druid,
                                   incoming_version: ver,
                                   incoming_size: size,
                                   storage_location: storage_location_param,
                                   checksums_validated: t_val }
        end
      end
    end

    describe 'incoming_size is required' do
      it 'incoming_size absent - errors' do
        patch :create, params: { druid: bare_druid, incoming_version: ver, storage_location: storage_location_param }
        expect(response).to have_http_status(:not_acceptable)
        expect(response.body).to match(/encountered validation error\(s\):.*Incoming size is not a number/)
      end

      it 'incoming size present - no errors' do
        patch :create, params: { druid: bare_druid, incoming_version: ver, incoming_size: size, storage_location: storage_location_param }
        expect(response).to have_http_status(:created)
        expect(response.body).not_to include('encountered validation error(s):')
      end
    end
  end
end
