require 'rails_helper'

describe ResultsRecorderJob, type: :job do
  let(:pc) { create(:archive_preserved_copy) }
  let(:druid)    { pc.preserved_object.druid }
  let(:endpoint) { pc.archive_endpoint }

  before { pc.archive_preserved_copy_parts.create(attributes_for(:archive_preserved_copy_part)) }

  it 'descends from ApplicationJob' do
    expect(described_class.new).to be_an(ApplicationJob)
  end

  it 'sets the ArchivePreservedCopyPart status to ok' do
    described_class.perform_now(druid, pc.version, 'fake.zip', endpoint.delivery_class.to_s)
    expect(pc.reload).to be_ok
  end

  context 'when all endpoints are fulfilled' do
    it 'posts a message to replication.results queue' do
      hash = { druid: druid, version: pc.version, endpoints: [endpoint.endpoint_name] }
      expect(Resque.redis.redis).to receive(:lpush).with('replication.results', hash.to_json)
      described_class.perform_now(druid, pc.version, 'fake.zip', endpoint.delivery_class.to_s)
    end
  end

  context 'when other endpoints remain unreplicated' do
    let(:other_ep) { create(:archive_endpoint, delivery_class: 2) }

    before do
      create(:archive_preserved_copy, preserved_copy: pc.preserved_copy, archive_endpoint: other_ep)
    end

    it 'does not send to replication.results queue' do
      expect(Resque.redis.redis).not_to receive(:lpush)
      described_class.perform_now(druid, pc.version, 'fake.zip', endpoint.delivery_class.to_s)
    end
  end
end
