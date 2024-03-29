# frozen_string_literal: true

require 'rails_helper'

describe Replication::ResultsRecorderJob do
  let(:preserved_object) { create(:preserved_object) }
  let(:zmv) { preserved_object.zipped_moab_versions.first }
  let(:zmv2) { preserved_object.zipped_moab_versions.second }
  let(:druid) { preserved_object.druid }
  let(:zip_endpoint) { zmv.zip_endpoint }
  let(:zip_endpoint2) { zmv2.zip_endpoint }
  let(:zip_part_attributes) { [attributes_for(:zip_part)] }
  let(:druid_version_zip) { Replication::DruidVersionZip.new(druid, zmv.version) }

  before do
    # creating the MoabRecord triggers associated ZippedMoabVersion creation via AR hooks
    create(:moab_record, preserved_object: preserved_object, version: preserved_object.current_version)
    zmv.zip_parts.create(zip_part_attributes)
    zmv2.zip_parts.create(zip_part_attributes)
    allow(Dor::Event::Client).to receive(:create).and_return(true)
    allow(Socket).to receive(:gethostname).and_return('fakehost')
  end

  it 'descends from ApplicationJob' do
    expect(described_class.new).to be_an(ApplicationJob)
  end

  it 'sets part status to ok' do
    expect { described_class.perform_now(druid, zmv.version, druid_version_zip.s3_key, zip_endpoint.delivery_class.to_s) }
      .to change { zmv.zip_parts.first.status }.from('unreplicated').to('ok')
  end

  context 'when there are multiple parts' do
    let(:zip_part_attributes) do
      base_attrs = attributes_for(:zip_part, parts_count: 3)
      [base_attrs.merge({ suffix: '.z01' }),
       base_attrs.merge({ suffix: '.z02' }),
       base_attrs.merge({ suffix: '.zip' })]
    end

    context 'when there are parts that are not yet replicated' do
      before do
        described_class.perform_now(druid, zmv.version, druid_version_zip.s3_key('.z01'), zip_endpoint.delivery_class.to_s)
        described_class.perform_now(druid, zmv.version, druid_version_zip.s3_key('.zip'), zip_endpoint.delivery_class.to_s)
      end

      it 'does not emit an event to the event service' do
        expect(Dor::Event::Client).not_to have_received(:create)
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
          druid: "druid:#{druid}",
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
        expect(Dor::Event::Client).to have_received(:create).with(event_info)
      end
    end
  end

  context 'when other endpoints remain unreplicated' do
    let(:other_ep) { create(:zip_endpoint, delivery_class: 2) }
    let(:redis) { instance_double(Redis, del: nil) }

    before do
      allow(Sidekiq).to receive(:redis).and_yield(redis)
      preserved_object.zipped_moab_versions.create!(version: zmv.version, zip_endpoint: other_ep)
    end

    it 'does not send to replication.results queue' do
      expect(redis).not_to receive(:lpush)
      described_class.perform_now(druid, zmv.version, druid_version_zip.s3_key, zip_endpoint.delivery_class.to_s)
    end
  end
end
