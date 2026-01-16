# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ZipEndpoint do
  let(:druid) { 'ab123cd4567' }
  let!(:zip_endpoint) { create(:zip_endpoint, endpoint_name: 'zip-endpoint', endpoint_node: 'us-west-01') }

  it 'is not valid unless it has all required attributes' do
    expect(described_class.new(delivery_class: 1)).not_to be_valid
    expect(described_class.new(endpoint_name: 'aws')).not_to be_valid
    expect(zip_endpoint).to be_valid
  end

  it 'enforces unique constraint on endpoint_name (model level)' do
    expect do
      described_class.create!(endpoint_name: 'zip-endpoint', delivery_class: 'Replication::S3EastDeliveryJob')
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'enforces unique constraint on endpoint_name (db level)' do
    expect do
      described_class.new(endpoint_name: 'zip-endpoint', delivery_class: 1).save(validate: false)
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'has multiple delivery_classes' do
    expect(described_class.delivery_classes).to include('Replication::S3WestDeliveryJob', 'Replication::S3EastDeliveryJob')
  end

  it { is_expected.to have_many(:zipped_moab_versions) }
  it { is_expected.to have_db_index(:endpoint_name) }
  it { is_expected.to validate_presence_of(:endpoint_name) }
  it { is_expected.to validate_presence_of(:delivery_class) }

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
          storage_location: endpoint_config.storage_location,
          delivery_class: endpoint_config.delivery_class
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
            storage_location: 'storage_location',
            delivery_class: 'Replication::S3WestDeliveryJob'
          )
      )
      allow(Settings).to receive(:zip_endpoints).and_return(zip_endpoints_setting)

      # run it a second time
      described_class.seed_from_config
      expected_ep_names = %w[aws_s3_west_2 fixture_archiveTest gcp_s3_south_1 ibm_us_south zip-endpoint]
      expect(described_class.pluck(:endpoint_name).sort).to eq expected_ep_names
    end

    it 'alerts and continues if a settings entry is not addable (allows e.g. partial initial config of credentials via env var)' do
      zip_endpoints_setting = Config::Options.new(
        forthcoming_s3_north_endpoint:
          Config::Options.new(
            secret_access_key: 'sdXSDr+asdfe/lkljoWEDCljdE+aTWrefc'
          )
      )
      logger = instance_double(Logger, warn: nil)
      allow(described_class).to receive(:logger).and_return(logger)
      allow(Settings).to receive(:zip_endpoints).and_return(zip_endpoints_setting)
      allow(Honeybadger).to receive(:notify)

      # run it a second time
      described_class.seed_from_config
      expected_ep_names = %w[aws_s3_west_2 gcp_s3_south_1 ibm_us_south zip-endpoint]
      expect(described_class.pluck(:endpoint_name).sort).to eq expected_ep_names
      expect(Honeybadger).to have_received(:notify).with(
        'Error trying to insert record for new zip endpoint, skipping entry',
        error_class: 'ActiveRecord::RecordInvalid',
        backtrace: include(a_string_matching(%r{app/models/zip_endpoint.rb})),
        context: { error_messages: ["Delivery class can't be blank"] }
      )
      expect(logger).to have_received(:warn).with(
        "Error trying to insert record for new zip endpoint, skipping entry: [\"Delivery class can't be blank\"]"
      )
    end

    # TODO: add a test for Settings.zip_endpoint changing an attribute other than the endpoint_name
  end
end
