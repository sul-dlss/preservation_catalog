require 'rails_helper'

describe ResultsRecorderJob, type: :job do
  let(:cm) { create(:complete_moab) }
  let(:zmv) { cm.zipped_moab_versions.first }
  let(:ibm_zmv) { cm.zipped_moab_versions.second }
  let(:druid) { zmv.preserved_object.druid }
  let(:ibm_druid) { ibm_zmv.preserved_object.druid }
  let(:zip_endpoint) { zmv.zip_endpoint }
  let(:ibm_zip_endpoint) { ibm_zmv.zip_endpoint }

  before do
    zmv.zip_parts.create(attributes_for(:zip_part))
    ibm_zmv.zip_parts.create(attributes_for(:zip_part))
  end

  it 'descends from ApplicationJob' do
    expect(described_class.new).to be_an(ApplicationJob)
  end

  context 'when all parts for zip_endpoint are replicated' do
    it 'sets part status to ok' do
      expect {
        described_class.perform_now(druid, zmv.version, 'fake.zip', zip_endpoint.delivery_class.to_s)
      }.to change {
        zmv.zip_parts.first.status
      }.from("unreplicated").to("ok")
    end
  end

  context 'when all zip_endpoints are fulfilled' do
    it 'posts a message to replication.results queue' do
      hash = { druid: druid, version: zmv.version, zip_endpoints: [ibm_zip_endpoint.endpoint_name, zip_endpoint.endpoint_name] }
      expect(Resque.redis.redis).to receive(:lpush).with('replication.results', hash.to_json)
      described_class.perform_now(druid, zmv.version, 'fake.zip', zip_endpoint.delivery_class.to_s)
      described_class.perform_now(ibm_druid, ibm_zmv.version, 'fake.zip', 'IbmSouthDeliveryJob')
    end
  end

  context 'when other endpoints remain unreplicated' do
    let(:other_ep) { create(:zip_endpoint, delivery_class: 2) }

    before do
      cm.zipped_moab_versions.create!(version: zmv.version, zip_endpoint: other_ep)
    end

    it 'does not send to replication.results queue' do
      expect(Resque.redis.redis).not_to receive(:lpush)
      described_class.perform_now(druid, zmv.version, 'fake.zip', zip_endpoint.delivery_class.to_s)
    end
  end
end
