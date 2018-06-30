require 'rails_helper'

describe 'the whole replication pipeline', type: :job do # rubocop:disable RSpec/DescribeClass
  let(:s3_object) { instance_double(Aws::S3::Object, exists?: false, put: true) }
  let(:bucket) { instance_double(Aws::S3::Bucket, object: s3_object) }
  let(:druid) { pc.preserved_object.druid }
  let(:version) { pc.version }
  let(:deliverer) { S3WestDeliveryJob.to_s }
  let(:hash) do
    { druid: druid, version: version, endpoints: [pc.endpoint.endpoint_name] }
  end
  let(:pc) { create(:unreplicated_copy_deprecated) }

  around do |example|
    old_adapter = ApplicationJob.queue_adapter
    ApplicationJob.queue_adapter = :inline
    example.run
    ApplicationJob.queue_adapter = old_adapter
  end

  before do
    FactoryBot.reload # we need the "first" PO, bj102hs9687, for PC to line up w/ fixture
    allow(Settings).to receive(:zip_storage).and_return(Rails.root.join('spec', 'fixtures', 'zip_storage'))
    allow(PreservationCatalog::S3).to receive(:bucket).and_return(bucket)
  end

  it 'gets from zipmaker queue to replication result message' do
    expect(PlexerJob).to receive(:perform_later).with(druid, version, Hash).and_call_original
    expect(S3WestDeliveryJob).to receive(:perform_later).with(druid, version, Hash).and_call_original
    # other endpoints as added...
    expect(ResultsRecorderJob).to receive(:perform_later).with(druid, version, deliverer).and_call_original
    expect(Resque.redis.redis).to receive(:lpush).with('replication.results', hash.to_json)
    ZipmakerJob.perform_now(druid, version)
  end
end
