require 'rails_helper'
RSpec.describe CatalogController, type: :controller do
  let(:size) { 2342 }
  let(:ver) { 3 }
  let(:prefixed_druid) { 'druid:bj102hs9687' }
  let(:bare_druid) { 'bj102hs9687' }
  let(:storage_location) { "#{storage_location_param}/moab_storage_trunk" }
  let(:storage_location_param) { "spec/fixtures/storage_root01" }

  describe 'POST #create' do
    context 'with valid params' do
      let(:pres_obj) { PreservedObject.find_by(druid: bare_druid) }
      let(:pres_copy) { PreservedCopy.find_by(preserved_object: pres_obj) }

      before do
        post :create, params: { druid: prefixed_druid, incoming_version: ver, incoming_size: size, storage_location: storage_location_param }
      end

      it 'saves PreservedObject and PreservedCopy in db' do
        po = PreservedObject.find_by(druid: bare_druid)
        pc = PreservedCopy.find_by(preserved_object: po)
        expect(po).to be_an_instance_of PreservedObject
        expect(pc).to be_an_instance_of PreservedCopy
      end
      it 'PreservedCopy and PreservedObject have correct attributes' do
        expect(pres_copy.endpoint.storage_location).to eq storage_location
        expect(pres_copy.version).to eq ver
        expect(pres_copy.size).to eq size
        expect(pres_obj.druid).to eq bare_druid
      end

      it 'response contains create_new_object code ' do
        exp_msg = [{ AuditResults::CREATED_NEW_OBJECT => "added object to db as it did not exist" }]
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

      it 'does not save PreservedObject or PreservedCopy in db' do
        po = PreservedObject.find_by(druid: prefixed_druid)
        pc = PreservedCopy.find_by(preserved_object: po)
        expect(po).to be_nil
        expect(pc).to be_nil
      end

      it 'response contains error message' do
        errors = ["Druid can't be blank", "Druid is invalid"]
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
        exp_msg = [{ AuditResults::DB_OBJ_ALREADY_EXISTS => "PreservedObject db object already exists" }]
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
    before do
      po = PreservedObject.create!(
        druid: "bj102hs9687", current_version: ver, preservation_policy: PreservationPolicy.default_policy
      )
      PreservedCopy.create!(
        preserved_object: po,
        endpoint: Endpoint.find_by(storage_location: storage_location),
        version: ver,
        status: PreservedCopy::VALIDITY_UNKNOWN_STATUS
      )
    end
    let(:pres_obj) { PreservedObject.find_by(druid: bare_druid) }
    let(:pres_copy) { PreservedCopy.find_by(preserved_object: pres_obj) }

    context 'with valid params' do
      before do
        patch :update, params: { druid: prefixed_druid, incoming_version: upd_version, incoming_size: size, storage_location: storage_location_param }
      end
      let(:upd_version) { 4 }

      it 'updates the version' do
        expect(pres_copy.version).to eq upd_version
      end

      it 'returns an ok response code' do
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid params' do
      before do
        patch :update, params: { druid: prefixed_druid, incoming_version: ver, incoming_size: size, storage_location: nil }
      end
      it 'response contains error message' do
        errors = ["Endpoint must be an actual Endpoint"]
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
        error = "#<ActiveRecord::RecordNotFound: Couldn't find PreservedObject>"
        exp_msg = [{ AuditResults::DB_OBJ_DOES_NOT_EXIST => "#{error} db object does not exist" }]
        expect(response.body).to include(exp_msg.to_json)
      end

      it 'returns a not found error' do
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'pc po version mismatch' do
      before do
        pres_copy.version = pres_copy.version + 1
        pres_copy.save!
        patch :update, params: { druid: prefixed_druid, incoming_version: ver, incoming_size: size, storage_location: storage_location_param }
      end
      it 'response contains error message' do
        exp_msg = [{ AuditResults::PC_PO_VERSION_MISMATCH => "PreservedCopy online Moab version 4 does not match PreservedObject current_version 3" }]
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
        unexp_ver = "actual version (1) has unexpected relationship to PreservedCopy db version (3); ERROR!"
        ver_lt_db = "actual version (1) less than PreservedCopy db version (3); ERROR!"
        status_change = "PreservedCopy status changed from validity_unknown to unexpected_version_on_storage"
        exp_msg = [
          { AuditResults::UNEXPECTED_VERSION => unexp_ver.to_s },
          { AuditResults::ACTUAL_VERS_LT_DB_OBJ => ver_lt_db.to_s },
          { AuditResults::PC_STATUS_CHANGED => status_change.to_s }
        ]
        expect(response.body).to include(exp_msg.to_json)
      end

      it 'returns an internal server error' do
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'db update failed' do
      before do
        allow(PreservedObject).to receive(:find_by!).with(druid: bare_druid)
                                                    .and_raise(ActiveRecord::ActiveRecordError, 'foo')
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

  describe 'Routing' do
    let(:druid) { "xx000xx0000" }

    it { is_expected.to route(:post, '/catalog').to(controller: :catalog, action: :create) }
    it { is_expected.to route(:patch, "/catalog/#{druid}").to(controller: :catalog, action: :update, druid: druid) }
  end
end
