require 'rails_helper'

RSpec.describe ArchiveEndpoint, type: :model do
  let(:default_pres_policies) { [PreservationPolicy.default_policy] }
  let(:druid) { 'ab123cd4567' }
  let!(:archive_endpoint) { create(:archive_endpoint, endpoint_name: 'archive-endpoint', endpoint_node: 'us-west-01') }

  it 'is not valid unless it has all required attributes' do
    expect(described_class.new(delivery_class: 1)).not_to be_valid
    expect(described_class.new(endpoint_name: 'aws')).not_to be_valid
    expect(archive_endpoint).to be_valid
  end

  it 'enforces unique constraint on endpoint_name (model level)' do
    expect do
      described_class.create!(endpoint_name: 'archive-endpoint', delivery_class: S3EastDeliveryJob)
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'enforces unique constraint on endpoint_name (db level)' do
    expect do
      described_class.new(endpoint_name: 'archive-endpoint', delivery_class: 1).save(validate: false)
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'has multiple delivery_classes' do
    expect(described_class.delivery_classes).to include(S3WestDeliveryJob, S3EastDeliveryJob)
  end

  it { is_expected.to have_many(:archive_preserved_copies) }
  it { is_expected.to have_db_index(:endpoint_name) }
  # TODO: add indexes
  # it { is_expected.to have_db_index(:endpoint_node) }
  # it { is_expected.to have_db_index(:storage_location) }
  it { is_expected.to have_and_belong_to_many(:preservation_policies) }
  it { is_expected.to validate_presence_of(:endpoint_name) }
  it { is_expected.to validate_presence_of(:delivery_class) }

  describe '.seed_archive_endpoints_from_config' do
    it 'creates an endpoints entry for each archive endpoint' do
      Settings.archive_endpoints.each do |endpoint_name, endpoint_config|
        archive_endpoint_attrs = {
          endpoint_node: endpoint_config.endpoint_node,
          storage_location: endpoint_config.storage_location,
          preservation_policies: default_pres_policies,
          delivery_class: S3WestDeliveryJob
        }
        expect(described_class.find_by(endpoint_name: endpoint_name)).to have_attributes(archive_endpoint_attrs)
      end
    end

    it 'does not re-create records that already exist' do
      # run it a second time
      expect { described_class.seed_archive_endpoints_from_config(default_pres_policies) }
        .not_to change { described_class.pluck(:endpoint_name).sort }
        .from(%w[archive-endpoint mock_archive1])
    end

    it 'adds new records if there are additions to Settings since the last run' do
      archive_endpoints_setting = Config::Options.new(
        fixture_archiveTest:
          Config::Options.new(
            endpoint_node: 'endpoint_node',
            storage_location: 'storage_location',
            delivery_class: 'S3WestDeliveryJob'
          )
      )
      allow(Settings).to receive(:archive_endpoints).and_return(archive_endpoints_setting)

      # run it a second time
      described_class.seed_archive_endpoints_from_config(default_pres_policies)
      expected_ep_names = %w[archive-endpoint fixture_archiveTest mock_archive1]
      expect(described_class.pluck(:endpoint_name).sort).to eq expected_ep_names
    end
  end
end
