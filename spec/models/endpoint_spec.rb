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
end
