require 'rails_helper'

RSpec.describe PreservationCopy, type: :model do
  let!(:preservation_object2) do
    PreservedObject.create!(druid: 'ab123cd45679', current_version: 1, preservation_policy: 'keepit', size: 1)
  end
  let!(:endpoint2) { Endpoint.create!(endpoint_name: 'oracle', endpoint_type: 'cloud') }
  let!(:preservation_copy) do
    PreservationCopy.create!(
      preserved_object_id: preservation_object2.id,
      endpoint_id: endpoint2.id,
      current_version: 0,
      status: 'fixity_error'
    )
  end

  it 'is not valid without valid attributes' do
    expect(PreservationCopy.new).not_to be_valid
  end

  it 'is not valid unless it has all required attributes' do
    expect(PreservationCopy.new(preserved_object_id: preservation_object2.id)).not_to be_valid
  end

  it 'is valid with valid attributes' do
    expect(preservation_copy).to be_valid
  end

  it { is_expected.to belong_to(:endpoint) }
  it { is_expected.to belong_to(:preserved_object) }
  it { is_expected.to have_db_index(:last_audited) }
  it { is_expected.to have_db_index(:endpoint_id) }
  it { is_expected.to have_db_index(:preserved_object_id) }
end
