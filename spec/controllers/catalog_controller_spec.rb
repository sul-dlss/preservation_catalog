require 'rails_helper'
RSpec.describe CatalogController, type: :controller do
  describe 'POST #create' do
    let(:size) { 2342 }
    let(:ver) { 3 }
    let(:endpoint_name) { 'fixture_sr1' }
    let(:druid) { 'bj102hs9687' }

    context 'with valid params' do
      let(:pres_copy) { PreservedCopy.first }
      let(:pres_obj) { PreservedObject.first }

      before do
        post :create, params: { druid: druid, incoming_version: ver, incoming_size: size, endpoint_name: endpoint_name }
      end

      it 'saves PreservedObject and PreservedCopy in db' do
        po = PreservedObject.find_by(druid: druid)
        pc = PreservedCopy.find_by(preserved_object: po)
        expect(po).to be_an_instance_of PreservedObject
        expect(pc).to be_an_instance_of PreservedCopy
      end
      it 'PreservedCopy and PreservedObject have correct attributes' do
        expect(pres_copy.endpoint.endpoint_name).to eq endpoint_name
        expect(pres_copy.version).to eq ver
        expect(pres_copy.size).to eq size
        expect(pres_obj.druid).to eq druid
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
        post :create, params: { druid: nil, incoming_version: ver, incoming_size: size, endpoint_name: endpoint_name }
      end

      it 'does not save PreservedObject or PreservedCopy in db' do
        po = PreservedObject.find_by(druid: druid)
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
        post :create, params: { druid: druid, incoming_version: ver, incoming_size: size, endpoint_name: endpoint_name }
        post :create, params: { druid: druid, incoming_version: ver, incoming_size: size, endpoint_name: endpoint_name }
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
        allow(PreservedObject).to receive(:create!).with(hash_including(druid: druid))
                                                   .and_raise(ActiveRecord::ActiveRecordError, 'foo')
        post :create, params: { druid: druid, incoming_version: ver, incoming_size: size, endpoint_name: endpoint_name }
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
      post :create, params: { druid: druid, incoming_version: ver, incoming_size: size, endpoint_name: endpoint_name }
      expect(response.body).to include(druid)
    end
  end
end
