require 'rails_helper'

RSpec.describe EndpointType, type: :model do
  let!(:endpoint_type) { EndpointType.create!(type_name: 'nfs', endpoint_class: 'online') }

  it 'is valid with valid attributes' do
    expect(endpoint_type).to be_valid
  end

  it 'is not valid without valid attributes' do
    expect(EndpointType.new).not_to be_valid
  end

  it 'enforces unique constraint on type_name' do
    expect do
      EndpointType.create!(type_name: 'nfs', endpoint_class: 'online')
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it { is_expected.to have_many(:endpoints) }
end
