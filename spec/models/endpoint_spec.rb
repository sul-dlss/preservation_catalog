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

  it 'enforces unique constraint on endpoint_name' do
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

  it { is_expected.to have_many(:preservation_copies) }
  it { is_expected.to have_db_index(:endpoint_name) }
  it { is_expected.to have_db_index(:endpoint_type_id) }
  it { is_expected.to have_and_belong_to_many(:preservation_policies) }
  it { is_expected.to belong_to(:endpoint_type) }

  describe '.seed_storage_root_endpoints_from_config' do
    # because of the above `let!`, using just `endpoint_type` as a name here blows up, because the shared name
    # would cause this `let` to be evaluated eagerly instead of lazily, and the EndpointType we want in this section
    # doesn't exist till the before block runs.
    let(:strg_rt_endpoint_type) { Endpoint.default_storage_root_endpoint_type }
    let(:default_pres_policies) { [PreservationPolicy.default_preservation_policy] }

    before do
      # Endpoint's going to try to use the default pres policy and endpoint type, so they should both get seeded first
      PreservationPolicy.seed_from_config
      EndpointType.seed_from_config
      Endpoint.seed_storage_root_endpoints_from_config(strg_rt_endpoint_type, default_pres_policies)
    end

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
      # sort so we can avoid comparing via include, and see that it has only/exactly the two expected elements
      expect(Endpoint.pluck(:endpoint_name).sort).to eq %w[aws fixtures]
    end

    it 'adds new records if there are additions to Settings since the last run' do
      storage_roots_setting = Config::Options.new(fixtures: 'spec/fixtures', fixtures2: 'spec/fixtures')
      allow(Settings.moab).to receive(:storage_roots).and_return(storage_roots_setting)

      # run it a second time
      Endpoint.seed_storage_root_endpoints_from_config(strg_rt_endpoint_type, default_pres_policies)
      expect(Endpoint.pluck(:endpoint_name).sort).to eq %w[aws fixtures fixtures2]
    end
  end

  describe '.default_storage_root_endpoint_type' do
    it 'returns the default endpoint type object for the storage root' do
      EndpointType.seed_from_config
      expect(Endpoint.default_storage_root_endpoint_type).to be_a_kind_of EndpointType
    end

    it "raises RecordNotFound if the default endpoint type doesn't exist in the db" do
      expect { Endpoint.default_storage_root_endpoint_type }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
