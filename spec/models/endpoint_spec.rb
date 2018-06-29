require 'rails_helper'

# TODO: make this spec run against only unseeded data
RSpec.describe Endpoint, type: :model do
  let(:default_pres_policies) { [PreservationPolicy.default_policy] }
  let(:druid) { 'ab123cd4567' }
  let(:endpoint_type) { build(:endpoint_type, type_name: 'aws', endpoint_class: 'archive') }
  let!(:endpoint) do
    create(
      :endpoint,
      endpoint_name: 'aws-us-east-2',
      endpoint_type: endpoint_type,
      endpoint_node: 's3.us-east-2.amazonaws.com',
      storage_location: 'sdr-bucket-01'
    )
  end

  it 'is not valid unless it has all required attributes' do
    expect(described_class.new).not_to be_valid
    expect(described_class.new(endpoint_name: 'aws')).not_to be_valid
    expect(endpoint).to be_valid
  end

  it 'enforces unique constraint on endpoint_name (model level)' do
    expect { endpoint.dup.save! }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'enforces unique constraint on endpoint_name (db level)' do
    expect { endpoint.dup.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'has multiple delivery_classes' do
    expect(described_class.delivery_classes).to include(S3WestDeliveryJob, S3EastDeliveryJob)
  end

  it { is_expected.to have_many(:preserved_copies) }
  it { is_expected.to have_db_index(:endpoint_name) }
  it { is_expected.to have_db_index(:endpoint_type_id) }
  it { is_expected.to have_db_index(:endpoint_node) }
  it { is_expected.to have_db_index(:storage_location) }
  it { is_expected.to have_and_belong_to_many(:preservation_policies) }
  it { is_expected.to belong_to(:endpoint_type) }
  it { is_expected.to validate_presence_of(:endpoint_name) }
  it { is_expected.to validate_presence_of(:endpoint_type) }
  it { is_expected.to validate_presence_of(:endpoint_node) }
  it { is_expected.to validate_presence_of(:storage_location) }

  describe '.ids_to_versions_found' do
    let(:po) { create :preserved_object, druid: druid, current_version: 3 }
    let(:seed_ep) { described_class.archive.first }
    let(:online_ep) { create(:endpoint) }

    before do
      po.preserved_copies.create!(
        (1..3).map { |v| { version: v, size: 1, status: 'ok', endpoint: endpoint } }
      )
      create(:preserved_object, current_version: 5).preserved_copies.create!( # unrelated PO keeps query honest
        (1..5).map { |v| { version: v, size: 1, status: 'ok', endpoint: endpoint } }
      )
    end

    it 'includes all relevant endpoint IDs, including those missing all versions' do
      hash = described_class.ids_to_versions_found(po.druid)
      expect(hash[seed_ep.id]).to eq []
      expect(hash[endpoint.id].sort).to eq [1, 2, 3]
    end

    it 'includes all relevant endpoint IDs and their found versions' do
      po.preserved_copies.create!(
        (2..3).map { |v| { version: v, size: 1, status: 'ok', endpoint: seed_ep } }
      )
      hash = described_class.ids_to_versions_found(po.druid)
      expect(hash[endpoint.id].sort).to eq([1, 2, 3])
      expect(hash[seed_ep.id].sort).to eq([2, 3])
    end
  end

  describe '.seed_storage_root_endpoints_from_config' do
    let(:endpoint_type) { EndpointType.default_for_storage_roots }

    it 'creates a local online endpoint for each storage root' do
      HostSettings.storage_roots.each do |storage_root_name, storage_root_location|
        storage_root_attrs = {
          endpoint_type: endpoint_type,
          endpoint_node: Settings.endpoints.storage_root_defaults.endpoint_node,
          storage_location: File.join(storage_root_location, Settings.moab.storage_trunk),
          preservation_policies: default_pres_policies
        }
        expect(Endpoint.find_by(endpoint_name: storage_root_name)).to have_attributes(storage_root_attrs)
      end
    end

    # run it a second time
    it 'does not re-create records that already exist' do
      expect { Endpoint.seed_storage_root_endpoints_from_config(endpoint_type, default_pres_policies) }
        .not_to change { Endpoint.pluck(:endpoint_name).sort }
        .from(%w[aws-us-east-2 fixture_empty fixture_sr1 fixture_sr2 fixture_sr3 mock_archive1])
    end

    it 'adds new records if there are additions to Settings since the last run' do
      storage_roots_setting = Config::Options.new(
        fixture_sr1: 'spec/fixtures/storage_root01',
        fixture_sr2: 'spec/fixtures/storage_root02',
        fixture_srTest: 'spec/fixtures/storage_root_unit_test'
      )
      allow(HostSettings).to receive(:storage_roots).and_return(storage_roots_setting)

      # run it a second time
      expect { Endpoint.seed_storage_root_endpoints_from_config(endpoint_type, default_pres_policies) }
        .to change { Endpoint.pluck(:endpoint_name).sort }
        .from(%w[aws-us-east-2 fixture_empty fixture_sr1 fixture_sr2 fixture_sr3 mock_archive1])
        .to(%w[aws-us-east-2 fixture_empty fixture_sr1 fixture_sr2 fixture_sr3 fixture_srTest mock_archive1])
    end
  end

  describe '.seed_archive_endpoints_from_config' do
    let(:endpoint_type) { EndpointType.find_by!(type_name: 'aws_s3') } # seeded from config

    it 'creates an endpoints entry for each archive endpoint' do
      Settings.archive_endpoints.each do |endpoint_name, endpoint_config|
        archive_endpoint_attrs = {
          endpoint_type: endpoint_type,
          endpoint_node: endpoint_config.endpoint_node,
          storage_location: endpoint_config.storage_location,
          preservation_policies: default_pres_policies,
          delivery_class: S3WestDeliveryJob
        }
        expect(Endpoint.find_by(endpoint_name: endpoint_name)).to have_attributes(archive_endpoint_attrs)
      end
    end

    it 'does not re-create records that already exist' do
      # run it a second time
      expect { Endpoint.seed_archive_endpoints_from_config(default_pres_policies) }
        .not_to change { Endpoint.pluck(:endpoint_name).sort }
        .from(%w[aws-us-east-2 fixture_empty fixture_sr1 fixture_sr2 fixture_sr3 mock_archive1])
    end

    it 'adds new records if there are additions to Settings since the last run' do
      archive_endpoints_setting = Config::Options.new(
        fixture_archiveTest:
          Config::Options.new(
            endpoint_type_name: endpoint_type.type_name,
            endpoint_node: 'endpoint_node',
            storage_location: 'storage_location',
            delivery_class: 'S3WestDeliveryJob'
          )
      )
      allow(Settings).to receive(:archive_endpoints).and_return(archive_endpoints_setting)

      # run it a second time
      Endpoint.seed_archive_endpoints_from_config(default_pres_policies)
      expected_ep_names = %w[aws-us-east-2 fixture_archiveTest fixture_empty fixture_sr1 fixture_sr2 fixture_sr3 mock_archive1]
      expect(Endpoint.pluck(:endpoint_name).sort).to eq expected_ep_names
    end
  end

  describe '.archive' do
    it 'returns only the archive endpoints' do
      expect(Endpoint.archive.pluck(:endpoint_name).sort).to eq(%w[aws-us-east-2 mock_archive1])
    end
  end

  describe '.archive_targets' do
    let!(:alternate_pres_policy) do
      PreservationPolicy.create!(preservation_policy_name: 'alternate_pres_policy',
                                 archive_ttl: 666,
                                 fixity_ttl: 666)
    end

    before { create(:preserved_object, druid: druid) }

    it "returns the archive endpoints which implement the PO's pres policy" do
      endpoint.preservation_policies = [PreservationPolicy.default_policy, alternate_pres_policy]
      expect(Endpoint.archive_targets(druid).pluck(:endpoint_name)).to eq %w[aws-us-east-2 mock_archive1]
      endpoint.preservation_policies = [alternate_pres_policy]
      expect(Endpoint.archive_targets(druid).pluck(:endpoint_name)).to eq %w[mock_archive1]
    end
  end

  describe '#to_h' do
    it 'has the expected values' do
      expect(endpoint.to_h).to eq(
        endpoint_name: 'aws-us-east-2',
        endpoint_type_name: 'aws',
        endpoint_type_class: 'archive',
        endpoint_node: 's3.us-east-2.amazonaws.com',
        storage_location: 'sdr-bucket-01'
      )
    end
  end

  describe '#to_s' do
    it 'just dumps the result of #to_h as a string, prefixed with the class name' do
      expect(endpoint.to_s).to match(/Endpoint.*#{Regexp.escape(endpoint.to_h.to_s)}/)
    end
  end

  describe '#validate_expired_checksums!' do
    it 'raises if endpoint is wrong type' do
      expect { endpoint.validate_expired_checksums! }.to raise_error(RuntimeError)
    end
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
