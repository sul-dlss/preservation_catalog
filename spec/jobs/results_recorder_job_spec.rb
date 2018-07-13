require 'rails_helper'

describe ResultsRecorderJob, type: :job do
  let(:zmv) { create(:zipped_moab_version) }
  let(:druid)    { zmv.preserved_object.druid }
  let(:endpoint) { zmv.archive_endpoint }

  before { zmv.zip_parts.create(attributes_for(:zip_part)) }

  it 'descends from ApplicationJob' do
    expect(described_class.new).to be_an(ApplicationJob)
  end

  context 'when all parts for endpoint are replicated' do
    it 'sets the ZippedMoabVersion status to ok' do
      described_class.perform_now(druid, zmv.version, 'fake.zip', endpoint.delivery_class.to_s)
      expect(zmv.reload).to be_ok
    end
    it 'sets part status to ok' do
      skip 'write test for individual part status'
    end
  end

  context 'when some parts for endpoint are replicated' do
    it 'does not set parent zipped_moab_version status to ok' do
      skip 'write test for parent zmv status'
    end
  end

  context 'when all endpoints are fulfilled' do
    it 'posts a message to replication.results queue' do
      hash = { druid: druid, version: zmv.version, endpoints: [endpoint.endpoint_name] }
      expect(Resque.redis.redis).to receive(:lpush).with('replication.results', hash.to_json)
      described_class.perform_now(druid, zmv.version, 'fake.zip', endpoint.delivery_class.to_s)
    end
  end

  context 'when other endpoints remain unreplicated' do
    let(:other_ep) { create(:archive_endpoint, delivery_class: 2) }

    before do
      create(:zipped_moab_version, preserved_copy: zmv.preserved_copy, archive_endpoint: other_ep)
    end

    it 'does not send to replication.results queue' do
      expect(Resque.redis.redis).not_to receive(:lpush)
      described_class.perform_now(druid, zmv.version, 'fake.zip', endpoint.delivery_class.to_s)
    end
  end
end
