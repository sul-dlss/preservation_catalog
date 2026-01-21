# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ZipEndpoint do
  let(:druid) { 'ab123cd4567' }
  let!(:zip_endpoint) { create(:zip_endpoint, endpoint_name: 'zip-endpoint', endpoint_node: 'us-west-01') }

  it 'is not valid when it has all required attributes' do
    expect(described_class.new(endpoint_name: 'aws')).to be_valid
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
    # NOTE: .seed_from_config has already been run or we wouldn't be able to run tests

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
      # run it a second time
      expect { described_class.seed_from_config }
        .not_to change { described_class.pluck(:endpoint_name).sort }
        .from(%w[aws_s3_west_2 gcp_s3_south_1 ibm_us_south zip-endpoint])
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
      expected_ep_names = %w[aws_s3_west_2 fixture_archiveTest gcp_s3_south_1 ibm_us_south zip-endpoint]
      expect(described_class.pluck(:endpoint_name).sort).to eq expected_ep_names
    end
  end
end
