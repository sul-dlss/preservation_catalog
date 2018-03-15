require 'rails_helper'
RSpec.describe CatalogController, type: :controller do
  describe 'POST #create' do
    let(:size) { 2342 }
    let(:version) { 3 }
    let(:endpoint) { Endpoint.first }
    let(:druid) { 'bj102hs9687' }

    context 'with valid params' do
      let(:pres_copy) { PreservedCopy.first }
      let(:pres_obj) { PreservedObject.first }

      before do
        post :create, params: { druid: druid, incoming_version: version, incoming_size: size, endpoint: endpoint }
      end

      it 'saves PreservedObject and PreservedCopy in db' do
        expect(PreservedObject).to exist
        expect(PreservedCopy).to exist
      end
      it 'PreservedCopy and PreservedObject have correct attributes' do
        expect(pres_copy.endpoint).to eq endpoint
        expect(pres_copy.version).to eq version
        expect(pres_copy.size).to eq size
        expect(pres_obj.druid).to eq druid
      end

      it 'response contains create_new_object code ' do
        code = AuditResults::CREATED_NEW_OBJECT
        exp_msg = "added object to db as it did not exist"
        post_response = response.request.env['action_controller.instance'].poh.handler_results.result_array
        expect(post_response).to include(a_hash_including(code => a_string_matching(exp_msg)))
      end

      # return a 204
      # 201 is created
    end

    # specific error case, create an item that already exists
    context 'with invalid params' do
      before do
        post :create, params: { druid: nil, incoming_version: version, incoming_size: size, endpoint: endpoint }
      end

      it 'does not save PreservedObject or PreservedCopy in db' do
        expect(PreservedObject).not_to exist
        expect(PreservedCopy).not_to exist
      end

      it 'response contains error message' do
        code = AuditResults::INVALID_ARGUMENTS
        exp_msg = "Druid can't be blank"
        response_error = response.request.env['action_controller.instance'].poh.handler_results.result_array
        expect(response_error).to include(a_hash_including(code => a_string_matching(exp_msg)))
      end
      # should return a 400 error or some error thats not 204. (add some code to controller) 
    end
  end
end
