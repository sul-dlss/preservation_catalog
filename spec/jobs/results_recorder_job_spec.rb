require 'rails_helper'

describe ResultsRecorderJob, type: :job do
  let(:pc) { create(:unreplicated_copy) }
  let(:druid)    { pc.preserved_object.druid }
  let(:endpoint) { pc.endpoint }

  it 'descends from ApplicationJob' do
    expect(described_class.new).to be_an(ApplicationJob)
  end

  it 'sets the PreservedCopy status to ok' do
    described_class.perform_now(druid, pc.version, endpoint.delivery_class.to_s, '12345ABC')
    expect(pc.reload).to be_ok
  end

  context 'when all endpoints are fulfilled' do
    it 'posts a message to replication.results queue' do
      hash = { druid: druid, version: pc.version, endpoints: [endpoint.endpoint_name] }
      expect(Resque.redis.redis).to receive(:lpush).with('replication.results', hash.to_json)
      described_class.perform_now(druid, pc.version, endpoint.delivery_class.to_s, '12345ABC')
    end
  end

  context 'when other endpoints remain unreplicated' do
    before { create(:unreplicated_copy, preserved_object: pc.preserved_object, endpoint: create(:archive_endpoint)) }

    it 'does not send to replication.results queue' do
      expect(Resque.redis.redis).not_to receive(:lpush)
      described_class.perform_now(druid, pc.version, endpoint.delivery_class.to_s, '12345ABC')
    end
  end
end
