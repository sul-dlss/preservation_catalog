# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ZipEndpoint do
  let(:druid) { 'ab123cd4567' }
  let!(:zip_endpoint) { create(:zip_endpoint, endpoint_name: 'zip-endpoint', endpoint_node: 'us-west-01') }

  it 'is valid when it has all required attributes' do
    expect(described_class.new(endpoint_name: 'aws', endpoint_node: 'us-west-2', storage_location: 'my-bucket')).to be_valid
    expect(zip_endpoint).to be_valid
  end

  describe '#bucket' do
    subject(:bucket) { described_class.find_by(endpoint_name: 'aws_s3_west_2').bucket }

    it 'returns an Aws::S3::Bucket' do
      expect(bucket).to be_a(Aws::S3::Bucket)
      expect(bucket.name).to eq(Settings.zip_endpoints.aws_s3_west_2.storage_location)
    end
  end

  describe '.seed_from_config' do
    before { described_class.seed_from_config }

    it 'creates a ZipEndpoint record for each Settings.zip_endpoint' do
      Settings.zip_endpoints.each do |endpoint_name, endpoint_config|
        zip_endpoint_attrs = {
          endpoint_node: endpoint_config.endpoint_node,
          storage_location: endpoint_config.storage_location
        }
        expect(described_class.find_by(endpoint_name: endpoint_name)).to have_attributes(zip_endpoint_attrs)
      end
    end

    it 'does not add ZipEndpoint records when Settings.zip_endpoint key names that already exist' do
      expect { described_class.seed_from_config }
        .not_to change { described_class.pluck(:endpoint_name).sort }
        .from(%w[aws_s3_west_2 gcp_s3_south_1 zip-endpoint])
    end

    it 'adds new ZipEndpoint record if there are new Settings.zip_endpoint key names' do
      zip_endpoints_setting = Config::Options.new(
        fixture_archiveTest:
          Config::Options.new(
            endpoint_node: 'new_endpoint_node',
            storage_location: 'storage_location'
          )
      )
      allow(Settings).to receive(:zip_endpoints).and_return(zip_endpoints_setting)

      # run it a second time
      described_class.seed_from_config
      expected_ep_names = %w[aws_s3_west_2 fixture_archiveTest gcp_s3_south_1 zip-endpoint]
      expect(described_class.pluck(:endpoint_name).sort).to eq expected_ep_names
    end

    context 'when a config entry is missing endpoint_node or storage_location' do
      let(:incomplete_config) do
        Config::Options.new(
          orphaned_endpoint: Config::Options.new(storage_location: 'some-bucket')
        )
      end

      before { allow(Settings).to receive(:zip_endpoints).and_return(incomplete_config) }

      it 'does not create a ZipEndpoint record' do
        expect { described_class.seed_from_config }
          .not_to(change { described_class.where(endpoint_name: 'orphaned_endpoint').count })
      end

      it 'logs a warning with a puppet remediation hint' do
        expect(described_class.logger).to receive(:warn).with(/need to be removed from puppet/)
        described_class.seed_from_config
      end

      it 'notifies Honeybadger' do
        expect(Honeybadger).to receive(:notify).with(anything, hash_including(context: { endpoint_name: 'orphaned_endpoint' }))
        described_class.seed_from_config
      end
    end
  end
end
