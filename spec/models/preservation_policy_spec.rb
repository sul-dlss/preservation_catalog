require 'rails_helper'

RSpec.describe PreservationPolicy, type: :model do
  let!(:preservation_policy) do
    PreservationPolicy.create!(preservation_policy_name: 'default',
                               archive_ttl: 604_800,
                               fixity_ttl: 604_800)
  end

  it 'is valid with valid attributes' do
    expect(preservation_policy).to be_valid
  end

  it 'is not valid without valid attributes' do
    expect(PreservationPolicy.new).not_to be_valid
  end

  it { is_expected.to have_many(:preserved_objects) }
  it { is_expected.to have_and_belong_to_many(:endpoints) }
end
