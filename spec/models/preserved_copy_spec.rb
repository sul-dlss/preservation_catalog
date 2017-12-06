require 'rails_helper'

RSpec.describe PreservedCopy, type: :model do
  let!(:endpoint) { Endpoint.first }
  let!(:preserved_object) do
    policy_id = PreservationPolicy.default_policy.id
    PreservedObject.create!(druid: 'ab123cd4567', current_version: 1, preservation_policy_id: policy_id)
  end
  let!(:status) { described_class::DEFAULT_STATUS }
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
      online_moab_not_found: 3,
      expected_version_not_found_online: 4,
      fixity_check_failed: 5
    )
  end

  context '#status=' do
    it "validation rejects an int value that's not actually used by the enum" do
      expect {
        PreservedCopy.new(
          preserved_object_id: preserved_object.id,
          endpoint_id: endpoint.id,
          version: 0,
          status: 654,
          size: 1
        )
      }.to raise_error(ArgumentError, "'654' is not a valid status")
    end

    it "validation rejects a value if it isn't one of the defined enum identifiers" do
      expect {
        PreservedCopy.new(
          preserved_object_id: preserved_object.id,
          endpoint_id: endpoint.id,
          version: 0,
          status: 'INVALID_MOAB',
          size: 1
        )
      }.to raise_error(ArgumentError, "'INVALID_MOAB' is not a valid status")
    end

    it "will accept a symbol, but will always return a string" do
      pc = PreservedCopy.new(
        preserved_object_id: preserved_object.id,
        endpoint_id: endpoint.id,
        version: 0,
        status: :invalid_moab,
        size: 1
      )
      expect(pc.status).to be_a(String)
      expect(pc.status).to eq 'invalid_moab'
    end
  end

  it { is_expected.to belong_to(:endpoint) }
  it { is_expected.to belong_to(:preserved_object) }
  it { is_expected.to have_db_index(:last_audited) }
  it { is_expected.to have_db_index(:endpoint_id) }
  it { is_expected.to have_db_index(:preserved_object_id) }
end
