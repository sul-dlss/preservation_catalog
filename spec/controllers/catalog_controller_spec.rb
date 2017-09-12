require 'rails_helper'

RSpec.describe CatalogController, type: :controller do
  describe 'POST #add_preserved_object' do
    context 'with valid params' do
      it 'saves the object with the expected field values' do
        allow(Stanford::StorageServices).to receive(:current_version).and_return(6)
        allow(subject).to receive(:moab_size).and_return(555)
        id = 'ab123cd45678'

        allow(PreservedObject).to receive(:create!)
        post :add_preserved_object, params: { id: id }
        expect(PreservedObject).to have_received(:create!).with(druid: id, size: 555, current_version: 6)
      end
    end

    context 'with invalid params' do
      it 'returns the unprocessable entity http status code' do
        post :add_preserved_object
        expect(response).to have_http_status(422)
      end
    end
  end

  describe 'PATCH #update' do
    context 'with valid params' do
      it 'updates the object with the expected field values' do
        allow(Stanford::StorageServices).to receive(:current_version).and_return(6)
        allow(subject).to receive(:moab_size).and_return(555)
        id = 'ab123cd45678'

        preserved_obj = instance_double(PreservedObject)
        allow(PreservedObject).to receive(:find_by).with(druid: id).and_return(preserved_obj)

        allow(preserved_obj).to receive(:update_attributes)
        put :update_preserved_object, params: { id: id }
        expect(preserved_obj).to have_received(:update_attributes).with(druid: id, size: 555, current_version: 6)
      end
    end
    context 'with invalid params' do
      it 'returns the unprocessable entity http status code' do
        put :update_preserved_object
        expect(response).to have_http_status(422)
      end
    end
  end
end
