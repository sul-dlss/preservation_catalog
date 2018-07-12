require 'rails_helper'

RSpec.describe Endpoint, type: :model do
  let(:default_pres_policies) { [PreservationPolicy.default_policy] }
  let(:druid) { 'ab123cd4567' }
  let!(:endpoint) do
    create(
      :endpoint,
      endpoint_name: 'storage-root-01',
      endpoint_node: 'localhost',
      storage_location: '/storage_root01'
    )
  end

  it 'is not valid unless it has all required attributes' do
    expect(Endpoint.new).not_to be_valid
    expect(Endpoint.new(endpoint_name: 'aws')).not_to be_valid
    expect(endpoint).to be_valid
  end

  it 'enforces unique constraint on endpoint_name (model level)' do
    expect do
      Endpoint.create!(endpoint.attributes.slice('endpoint_name', 'endpoint_type', 'endpoint_node', 'storage_location'))
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'enforces unique constraint on endpoint_name (db level)' do
    expect { endpoint.dup.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'has multiple delivery_classes' do
    expect(described_class.delivery_classes).to include(S3WestDeliveryJob, S3EastDeliveryJob)
  end

  it { is_expected.to have_many(:preserved_copies) }
  it { is_expected.to have_db_index(:endpoint_name) }
  it { is_expected.to have_db_index(:endpoint_node) }
  it { is_expected.to have_db_index(:storage_location) }
  it { is_expected.to have_and_belong_to_many(:preservation_policies) }
  it { is_expected.to validate_presence_of(:endpoint_name) }
  it { is_expected.to validate_presence_of(:endpoint_node) }
  it { is_expected.to validate_presence_of(:storage_location) }

  describe '.seed_storage_root_endpoints_from_config' do
    it 'creates a local online endpoint for each storage root' do
      HostSettings.storage_roots.each do |storage_root_name, storage_root_location|
        storage_root_attrs = {
          endpoint_node: Settings.endpoints.storage_root_defaults.endpoint_node,
          storage_location: File.join(storage_root_location, Settings.moab.storage_trunk),
          preservation_policies: default_pres_policies
        }
        expect(Endpoint.find_by(endpoint_name: storage_root_name)).to have_attributes(storage_root_attrs)
      end
    end

    # run it a second time
    it 'does not re-create records that already exist' do
      expect { Endpoint.seed_storage_root_endpoints_from_config(default_pres_policies) }
        .not_to change { Endpoint.pluck(:endpoint_name).sort }
        .from(%w[fixture_empty fixture_sr1 fixture_sr2 fixture_sr3 storage-root-01])
    end

    it 'adds new records if there are additions to Settings since the last run' do
      storage_roots_setting = Config::Options.new(
        fixture_sr1: 'spec/fixtures/storage_root01',
        fixture_sr2: 'spec/fixtures/storage_root02',
        fixture_srTest: 'spec/fixtures/storage_root_unit_test'
      )
      allow(HostSettings).to receive(:storage_roots).and_return(storage_roots_setting)

      # run it a second time
      expect { Endpoint.seed_storage_root_endpoints_from_config(default_pres_policies) }
        .to change { Endpoint.pluck(:endpoint_name).sort }
        .from(%w[fixture_empty fixture_sr1 fixture_sr2 fixture_sr3 storage-root-01])
        .to(%w[fixture_empty fixture_sr1 fixture_sr2 fixture_sr3 fixture_srTest storage-root-01])
    end
  end

  describe '#validate_expired_checksums!' do
    it 'calls ChecksumValidationJob for each eligible PreservedCopy' do
      allow(Rails.logger).to receive(:info)
      ep = create(:endpoint)
      ep.preserved_copies = build_list(:preserved_copy, 2)
      expect(ChecksumValidationJob).to receive(:perform_later).with(ep.preserved_copies.first)
      expect(ChecksumValidationJob).to receive(:perform_later).with(ep.preserved_copies.second)
      ep.validate_expired_checksums!
    end
  end
end
