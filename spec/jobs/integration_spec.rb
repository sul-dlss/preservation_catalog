# frozen_string_literal: true

require 'rails_helper'

describe 'the whole replication pipeline', type: :job do
  let(:aws_s3_object) { instance_double(::Aws::S3::Object, exists?: false, upload_file: true) }
  let(:ibm_s3_object) { instance_double(::Aws::S3::Object, exists?: false, upload_file: true) }
  let(:aws_bucket) { instance_double(::Aws::S3::Bucket, object: aws_s3_object) }
  let(:ibm_bucket) { instance_double(::Aws::S3::Bucket, object: ibm_s3_object) }
  let(:druid) { 'bz514sm9647' }
  let(:version) { 1 }
  let(:preserved_object) { create(:preserved_object, druid: druid, current_version: version) }
  let(:zip_endpoints) { preserved_object.preservation_policy.zip_endpoints }
  let(:hash) do
    {
      druid: druid,
      version: version,
      zip_endpoints: zip_endpoints.map(&:endpoint_name).sort
    }
  end
  let(:s3_key) { 'bz/514/sm/9647/bz514sm9647.v0001.zip' }
  let(:aws_provider) { instance_double(S3::AwsProvider, bucket: aws_bucket) }
  let(:ibm_provider) { instance_double(S3::IbmProvider, bucket: ibm_bucket) }
  let(:moab_storage_root) { MoabStorageRoot.find_by!(name: 'fixture_sr1') }

  around do |example|
    old_adapter = ApplicationJob.queue_adapter
    ApplicationJob.queue_adapter = :inline
    example.run
    ApplicationJob.queue_adapter = old_adapter
  end

  before do
    allow(Settings).to receive(:zip_storage).and_return(Rails.root.join('spec', 'fixtures', 'zip_storage'))
    allow(S3::AwsProvider).to receive(:new).and_return(aws_provider)
    allow(S3::IbmProvider).to receive(:new).and_return(ibm_provider)
    allow(Dor::Event::Client).to receive(:create)
    allow(Socket).to receive(:gethostname).and_return('fakehost')
  end

  after do
    FileUtils.rm_rf('spec/fixtures/zip_storage/bz/')
  end

  it 'gets from zipmaker queue to replication result message upon initial moab creation' do
    expect(ZipmakerJob).to receive(:perform_later).with(druid, version, moab_storage_root.storage_location).and_call_original
    expect(PlexerJob).to receive(:perform_later).with(druid, version, s3_key, Hash).and_call_original
    expect(S3WestDeliveryJob).to receive(:perform_later).with(druid, version, s3_key, Hash).and_call_original
    expect(IbmSouthDeliveryJob).to receive(:perform_later).with(druid, version, s3_key, Hash).and_call_original
    # other endpoints as added...
    expect(ResultsRecorderJob).to receive(:perform_later).with(druid, version, s3_key, 'S3WestDeliveryJob').and_call_original
    expect(ResultsRecorderJob).to receive(:perform_later).with(druid, version, s3_key, 'IbmSouthDeliveryJob').and_call_original
    expect(Dor::Event::Client).to receive(:create).with(
      druid: "druid:#{druid}",
      type: 'druid_version_replicated',
      data: a_hash_including({ host: 'fakehost', version: 1, endpoint_name: 'aws_s3_west_2' })
    )
    expect(Dor::Event::Client).to receive(:create).with(
      druid: "druid:#{druid}",
      type: 'druid_version_replicated',
      data: a_hash_including({ host: 'fakehost', version: 1, endpoint_name: 'ibm_us_south' })
    )
    expect(Resque.redis.redis).to receive(:lpush).with('replication.results', hash.to_json)

    # creating or updating a CompleteMoab should trigger its parent PreservedObject to replicate any missing versions to any target endpoints
    create(:complete_moab, preserved_object: preserved_object, version: version, moab_storage_root: moab_storage_root)
  end

  context 'updating an existing moab' do
    let(:version) { 2 }
    let(:next_version) { version + 1 }
    let(:s3_key) { "bz/514/sm/9647/bz514sm9647.v000#{next_version}.zip" }

    it 'gets from zipmaker queue to replication result message for the new version when the moab is updated' do
      # pretend catalog is on version 2 before update call from robots
      create(:complete_moab, preserved_object: preserved_object, version: version, moab_storage_root: moab_storage_root) do |cm|
        PreservedObjectsPrimaryMoab.create!(preserved_object: preserved_object, complete_moab: cm)
      end

      expect(ZipmakerJob).to receive(:perform_later).with(druid, next_version, moab_storage_root.storage_location).and_call_original
      expect(PlexerJob).to receive(:perform_later).with(druid, next_version, s3_key, Hash).and_call_original
      expect(S3WestDeliveryJob).to receive(:perform_later).with(druid, next_version, s3_key, Hash).and_call_original
      expect(IbmSouthDeliveryJob).to receive(:perform_later).with(druid, next_version, s3_key, Hash).and_call_original
      # other endpoints as added...
      expect(ResultsRecorderJob).to receive(:perform_later).with(druid, next_version, s3_key, 'S3WestDeliveryJob').and_call_original
      expect(ResultsRecorderJob).to receive(:perform_later).with(druid, next_version, s3_key, 'IbmSouthDeliveryJob').and_call_original
      expect(Dor::Event::Client).to receive(:create).with(
        druid: "druid:#{druid}",
        type: 'druid_version_replicated',
        data: a_hash_including({ host: 'fakehost', version: 3, endpoint_name: 'aws_s3_west_2' })
      )
      expect(Dor::Event::Client).to receive(:create).with(
        druid: "druid:#{druid}",
        type: 'druid_version_replicated',
        data: a_hash_including({ host: 'fakehost', version: 3, endpoint_name: 'ibm_us_south' })
      )
      expect(Resque.redis.redis).to receive(:lpush).with('replication.results', hash.merge(version: next_version).to_json)

      # updating the CompleteMoab#version and its PreservedObject#current_version should trigger the replication cycle again, on the new version
      CompleteMoabHandler.new(druid, next_version, 712, moab_storage_root).update_version(true)
    end
  end
end
