require 'rails_helper'

RSpec.describe PreservedCopy, type: :model do
  let!(:endpoint) { Endpoint.first }
  let!(:preserved_object) do
    policy_id = PreservationPolicy.default_preservation_policy.id
    PreservedObject.create!(druid: 'ab123cd4567', current_version: 1, preservation_policy_id: policy_id)
  end
  let!(:status) { "ok" }
  let!(:preserved_copy) do
    PreservedCopy.create!(
      preserved_object_id: preserved_object.id,
      endpoint_id: endpoint.id,
      version: 0,
      status: status,
      size: 1
    )
  end

  it 'is not valid without valid attributes' do
    expect(PreservedCopy.new).not_to be_valid
  end

  it 'is not valid unless it has all required attributes' do
    expect(PreservedCopy.new(preserved_object_id: preserved_object.id)).not_to be_valid
  end

  it 'is valid with valid attributes' do
    expect(preserved_copy).to be_valid
  end

  it 'defines a status enum with the expected values' do
    is_expected.to define_enum_for(:status).with(
      ok: 0,
      invalid_moab: 1,
      invalid_checksum: 2,
      not_found_on_disk: 3,
      expected_version_not_found_on_disk: 4,
      fixity_check_failed: 5
    )
  end

  it 'is not valid without an existing status' do
    expect {
      PreservedCopy.new(
        preserved_object_id: preserved_object.id,
        endpoint_id: endpoint.id,
        version: 0,
        status: 6,
        size: 1
      )
    }.to raise_error(ArgumentError, "'6' is not a valid status")
  end

  it { is_expected.to belong_to(:endpoint) }
  it { is_expected.to belong_to(:preserved_object) }
  it { is_expected.to have_db_index(:last_audited) }
  it { is_expected.to have_db_index(:endpoint_id) }
  it { is_expected.to have_db_index(:preserved_object_id) }
end
