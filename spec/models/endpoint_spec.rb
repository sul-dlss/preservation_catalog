require 'rails_helper'

RSpec.describe Endpoint, type: :model do

  let!(:endpoint_type) { EndpointType.create(type_name: 'aws', endpoint_class: 'archive') }
  let!(:endpoint) do
    Endpoint.create(
      endpoint_name: 'aws',
      endpoint_type_id: endpoint_type.id,
      endpoint_node: 'sul-sdr',
      storage_location: '/storage',
      recovery_cost: '1'
    )
  end

  it 'is not valid without valid attributes' do
    expect(Endpoint.new).not_to be_valid
  end

  it 'is not valid unless it has all required attributes' do
    expect(Endpoint.new(endpoint_name: 'aws')).not_to be_valid
  end

  it 'is valid with valid attributes' do
    expect(endpoint).to be_valid
  end

  it 'enforces unique constraint on endpoint_name (model level)' do
    expect do
      Endpoint.create!(
        endpoint_name: 'aws',
        endpoint_type_id: endpoint_type.id,
        endpoint_node: 'sul-sdr',
        storage_location: '/storage',
        recovery_cost: '1'
      )
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'enforces unique constraint on endpoint_name (db level)' do
    endpoint
    dup_endpoint = Endpoint.new
    dup_endpoint.endpoint_name = 'aws'
    dup_endpoint.endpoint_node = 'sul-sdr'
    dup_endpoint.storage_location = '/storage'
    dup_endpoint.recovery_cost = '1'
    dup_endpoint.endpoint_type_id = endpoint_type.id
    expect { dup_endpoint.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it { is_expected.to have_many(:preserved_copies) }
  it { is_expected.to have_db_index(:endpoint_name) }
  it { is_expected.to have_db_index(:endpoint_type_id) }
  it { is_expected.to have_db_index(:endpoint_node) }
  it { is_expected.to have_db_index(:storage_location) }
  it { is_expected.to have_and_belong_to_many(:preservation_policies) }
  it { is_expected.to belong_to(:endpoint_type) }

  describe '.seed_storage_root_endpoints_from_config' do
    # because of the above `let!`, using just `endpoint_type` as a name here blows up, because the shared name
    # would cause this `let` to be evaluated eagerly instead of lazily, and the EndpointType we want in this section
    # doesn't exist till the before block runs.
    let(:strg_rt_endpoint_type) { Endpoint.default_storage_root_endpoint_type }
    let(:default_pres_policies) { [PreservationPolicy.default_preservation_policy] }

    it 'creates a local online endpoint for each storage root' do
      Settings.moab.storage_roots.each do |storage_root_name, storage_root_location|
        storage_root_attrs = {
          endpoint_type: strg_rt_endpoint_type,
          endpoint_node: Settings.endpoints.storage_root_defaults.endpoint_node,
          storage_location: File.join(storage_root_location, Settings.moab.storage_trunk),
          recovery_cost: Settings.endpoints.storage_root_defaults.recovery_cost,
          preservation_policies: default_pres_policies
        }
        expect(Endpoint.find_by(endpoint_name: storage_root_name)).to have_attributes(storage_root_attrs)
      end
    end

    it 'does not re-create records that already exist' do
      # run it a second time
      Endpoint.seed_storage_root_endpoints_from_config(strg_rt_endpoint_type, default_pres_policies)
      # sort so we can avoid comparing via include, and see that it has only/exactly the four expected elements
      expect(Endpoint.pluck(:endpoint_name).sort).to eq %w[aws fixture_empty fixture_sr1 fixture_sr2]
    end

    it 'adds new records if there are additions to Settings since the last run' do
      storage_roots_setting = Config::Options.new(
        fixture_sr1: 'spec/fixtures/storage_root01',
        fixture_sr2: 'spec/fixtures/storage_root02',
        fixture_srTest: 'spec/fixtures/storage_root_unit_test'
      )
      allow(Settings.moab).to receive(:storage_roots).and_return(storage_roots_setting)

      # run it a second time
      Endpoint.seed_storage_root_endpoints_from_config(strg_rt_endpoint_type, default_pres_policies)
      expect(Endpoint.pluck(:endpoint_name).sort).to eq %w[aws fixture_empty fixture_sr1 fixture_sr2 fixture_srTest]
    end
  end

  describe '.default_storage_root_endpoint_type' do
    it 'returns the default endpoint type object for the storage root' do
      # db already seeded
      expect(Endpoint.default_storage_root_endpoint_type).to be_a_kind_of EndpointType
    end

    it "raises RecordNotFound if the default endpoint type doesn't exist in the db" do
      # a bit contrived, but just want to test that lack of default EndpointType for local storage roots causes
      # lookup to fail fast.  since db is already seeded, we just make it look up something that we know isn't there.
      allow(Settings.endpoints.storage_root_defaults).to receive(:endpoint_type_name).and_return('nonexistent')
      expect { Endpoint.default_storage_root_endpoint_type }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
