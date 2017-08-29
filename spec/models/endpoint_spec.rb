require 'rails_helper'

RSpec.describe Endpoint, type: :model do

  let!(:endpoint) { Endpoint.create(endpoint_name: 'aws', endpoint_type: 'cloud') }

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
      Endpoint.create!(endpoint_name: 'aws', endpoint_type: 'cloud')
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it { is_expected.to have_many(:preservation_copies) }
  it { is_expected.to have_db_index(:endpoint_name) }
  it { is_expected.to have_db_index(:endpoint_type) }
end
