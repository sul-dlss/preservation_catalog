require 'rails_helper'

RSpec.describe MoabStorageController, type: :controller do

  describe "GET #index" do
    it "returns http success status code" do
      get :index
      expect(response).to have_http_status(:success)
    end
    context 'assigns @stored_druids correctly' do
      it 'without current or parent dot directories' do
        get :index
        expect(assigns(:stored_druids)).not_to include('.', '..')
      end
      it 'with all the fixture druids' do
        get :index
        expect(assigns(:stored_druids)).to include('bj102hs9687', 'bp628nk4868', 'bz514sm9647', 'dc048cw1328')
      end
      it 'Array of Strings' do
        get :index
        expect(assigns(:stored_druids)).to be_an_instance_of Array
        expect(assigns(:stored_druids).first).to be_an_instance_of String
      end
    end
    it 'assigns @storage_root correctly' do
      get :index
      expect(assigns(:storage_root)).to eq "#{Moab::Config.storage_roots.first}/#{Moab::Config.storage_trunk}"
    end
    it 'returns json by default' do
      get :index
      expect(response.content_type).to eq "application/json"
    end
    it 'returns json when requested' do
      get :index, format: :json
      expect(response.content_type).to eq "application/json"
    end
    it 'returns xml when requested' do
      get :index, format: :xml
      expect(response.content_type).to eq "application/xml"
    end
  end

  describe "GET #show" do
    let(:fixture_druid) { 'bj102hs9687' }

    it "returns http success status code" do
      get :show, params: { id: fixture_druid }
      expect(response).to have_http_status(:success)
    end

    context 'assigns @output correctly' do
      it 'Hash' do
        get :show, params: { id: fixture_druid }
        expect(assigns(:output)).to be_an_instance_of Hash
      end
      it 'current_version' do
        get :show, params: { id: fixture_druid }
        expect(assigns(:output)[:current_version]).to eq 3
      end

      it 'object_size' do
        get :show, params: { id: fixture_druid }
        expect(assigns(:output)[:object_size]).to be_between(1_900_000, 2_100_000)
      end

      it 'object_size_human' do
        get :show, params: { id: fixture_druid }
        expect(assigns(:output)[:object_size_human]).to a_string_ending_with("MB")
      end

    end
    it 'returns json by default' do
      get :show, params: { id: fixture_druid }
      expect(response.content_type).to eq "application/json"
    end
    it 'returns json when requested' do
      get :show, params: { id: fixture_druid, format: :json }
      expect(response.content_type).to eq "application/json"
    end
    it 'returns xml when requested' do
      get :show, params: { id: fixture_druid, format: :xml }
      expect(response.content_type).to eq "application/xml"
    end
  end
end
