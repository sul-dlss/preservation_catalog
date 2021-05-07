# frozen_string_literal: true

require 'rails_helper'

describe ResultsRecorderJob, type: :job do
  let(:preserved_object) { create(:preserved_object) }
  let(:zmv) { preserved_object.zipped_moab_versions.first }
  let(:zmv2) { preserved_object.zipped_moab_versions.second }
  let(:druid) { preserved_object.druid }
  let(:zip_endpoint) { zmv.zip_endpoint }
  let(:zip_endpoint2) { zmv2.zip_endpoint }
  let(:zip_part_attributes) { [attributes_for(:zip_part)] }
  let(:druid_version_zip) { DruidVersionZip.new(druid, zmv.version) }
  let(:events_client) { instance_double(Dor::Services::Client::Events, create: nil) }

  before do
    # creating the CompleteMoab triggers associated ZippedMoabVersion creation via AR hooks
    create(:complete_moab, preserved_object: preserved_object, version: preserved_object.current_version)
    zmv.zip_parts.create(zip_part_attributes)
    zmv2.zip_parts.create(zip_part_attributes)
    allow(Dor::Services::Client).to receive(:object).with("druid:#{druid}").and_return(
      instance_double(Dor::Services::Client::Object, events: events_client)
    )
    allow(events_client).to receive(:create)
    allow(Socket).to receive(:gethostname).and_return('fakehost')
  end

  it 'descends from ApplicationJob' do
    expect(described_class.new).to be_an(ApplicationJob)
  end

  it 'sets part status to ok' do
    expect {
      described_class.perform_now(druid, zmv.version, druid_version_zip.s3_key, zip_endpoint.delivery_class.to_s)
    }.to change {
      zmv.zip_parts.first.status
    }.from('unreplicated').to('ok')
  end

  context 'when there are multiple parts' do
    let(:zip_part_attributes) {
      base_attrs = attributes_for(:zip_part, parts_count: 3)
      [base_attrs.merge({ suffix: '.z01' }),
       base_attrs.merge({ suffix: '.z02' }),
       base_attrs.merge({ suffix: '.zip' })]
    }

    context 'when there are parts that are not yet replicated' do
      before do
        described_class.perform_now(druid, zmv.version, druid_version_zip.s3_key('.z01'), zip_endpoint.delivery_class.to_s)
        described_class.perform_now(druid, zmv.version, druid_version_zip.s3_key('.zip'), zip_endpoint.delivery_class.to_s)
      end

      it 'does not emit an event to the event service' do
        expect(events_client).not_to have_received(:create)
      end
    end

    context 'when all parts for zip_endpoint are replicated' do
      before do
        described_class.perform_now(druid, zmv.version, druid_version_zip.s3_key('.z01'), zip_endpoint.delivery_class.to_s)
        described_class.perform_now(druid, zmv.version, druid_version_zip.s3_key('.z02'), zip_endpoint.delivery_class.to_s)
        described_class.perform_now(druid, zmv.version, druid_version_zip.s3_key('.zip'), zip_endpoint.delivery_class.to_s)
      end

      it 'emits an event to the event service with info about the replicated parts' do
        event_info = {
          type: 'druid_version_replicated',
          data: {
            host: 'fakehost',
            invoked_by: 'preservation-catalog',
            version: zmv.version,
            endpoint_name: zmv.zip_endpoint.endpoint_name,
            parts_info: [
              { s3_key: druid_version_zip.s3_key('.z01'), size: 1234, md5: '00236a2ae558018ed13b5222ef1bd977' },
              { s3_key: druid_version_zip.s3_key('.z02'), size: 1234, md5: '00236a2ae558018ed13b5222ef1bd977' },
              { s3_key: druid_version_zip.s3_key('.zip'), size: 1234, md5: '00236a2ae558018ed13b5222ef1bd977' }
            ]
          }
        }
        expect(events_client).to have_received(:create).with(event_info)
      end
    end
  end

  context 'when all zip_endpoints are fulfilled' do
    it 'posts a message to replication.results queue' do
      hash = { druid: druid, version: zmv.version, zip_endpoints: [zip_endpoint.endpoint_name, zip_endpoint2.endpoint_name].sort }
      expect(Resque.redis.redis).to receive(:lpush).with('replication.results', hash.to_json)
      described_class.perform_now(druid, zmv.version, druid_version_zip.s3_key, zip_endpoint.delivery_class.to_s)
      described_class.perform_now(druid, zmv2.version, druid_version_zip.s3_key, zip_endpoint2.delivery_class.to_s)
    end
  end

  context 'when other endpoints remain unreplicated' do
    let(:other_ep) { create(:zip_endpoint, delivery_class: 2) }

    before do
      preserved_object.zipped_moab_versions.create!(version: zmv.version, zip_endpoint: other_ep)
    end

    it 'does not send to replication.results queue' do
      expect(Resque.redis.redis).not_to receive(:lpush)
      described_class.perform_now(druid, zmv.version, druid_version_zip.s3_key, zip_endpoint.delivery_class.to_s)
    end
  end
end
