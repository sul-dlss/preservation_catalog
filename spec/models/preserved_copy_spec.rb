require 'rails_helper'

RSpec.describe PreservedCopy, type: :model do
  let!(:endpoint) { Endpoint.first }
  let!(:preserved_object) do
    policy_id = PreservationPolicy.default_policy.id
    PreservedObject.create!(druid: 'ab123cd4567', current_version: 1, preservation_policy_id: policy_id)
  end
  let!(:status) { described_class::VALIDITY_UNKNOWN_STATUS }
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
      PreservedCopy::OK_STATUS => 0,
      PreservedCopy::INVALID_MOAB_STATUS => 1,
      PreservedCopy::INVALID_CHECKSUM_STATUS => 2,
      PreservedCopy::ONLINE_MOAB_NOT_FOUND_STATUS => 3,
      PreservedCopy::EXPECTED_VERS_NOT_FOUND_ON_STORAGE_STATUS => 4,
      PreservedCopy::FIXITY_CHECK_FAILED_STATUS => 5,
      PreservedCopy::VALIDITY_UNKNOWN_STATUS => 6
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
      expect(pc.status).to eq PreservedCopy::INVALID_MOAB_STATUS
    end
  end

  it { is_expected.to belong_to(:endpoint) }
  it { is_expected.to belong_to(:preserved_object) }
  it { is_expected.to have_db_index(:last_version_audit) }
  it { is_expected.to have_db_index(:last_moab_validation) }
  it { is_expected.to have_db_index(:last_checksum_validation) }
  it { is_expected.to have_db_index(:endpoint_id) }
  it { is_expected.to have_db_index(:preserved_object_id) }

  describe '#update_audit_timestamps' do
    let(:pc) do
      PreservedCopy.new(
        preserved_object_id: preserved_object.id,
        endpoint_id: endpoint.id,
        version: 0,
        status: PreservedCopy::INVALID_MOAB_STATUS,
        size: 1
      )
    end

    it 'updates last_moab_validation time if moab_validated is true' do
      expect(pc.last_moab_validation).to be nil
      pc.update_audit_timestamps(true, false)
      expect(pc.last_moab_validation).not_to be nil
    end
    it 'does not update last_moab_validation time if moab_validated is false' do
      expect(pc.last_moab_validation).to be nil
      pc.update_audit_timestamps(false, false)
      expect(pc.last_moab_validation).to be nil
    end
    it 'updates last_version_audit time if version_audited is true' do
      expect(pc.last_version_audit).to be nil
      pc.update_audit_timestamps(false, true)
      expect(pc.last_version_audit).not_to be nil
    end
    it 'does not update last_version_audit time if version_audited is false' do
      expect(pc.last_version_audit).to be nil
      pc.update_audit_timestamps(false, false)
      expect(pc.last_version_audit).to be nil
    end
  end

  describe '#upd_audstamps_version_size' do
    let(:pc) do
      PreservedCopy.new(
        preserved_object_id: preserved_object.id,
        endpoint_id: endpoint.id,
        version: 0,
        status: PreservedCopy::INVALID_MOAB_STATUS,
        size: 1
      )
    end

    it 'updates version' do
      pc.upd_audstamps_version_size(false, 3, nil)
      expect(pc.version).to eq 3
    end

    it 'updates size if size is not nil' do
      pc.upd_audstamps_version_size(false, 0, 123)
      expect(pc.size).to eq 123
    end

    it 'does not update size if size is nil' do
      pc.upd_audstamps_version_size(false, 0, nil)
      expect(pc.size).to eq 1
    end

    it 'calls update_audit_timestamps with the appropriate params' do
      expect(pc).to receive(:update_audit_timestamps).with(false, true)
      pc.upd_audstamps_version_size(false, 3, nil)
    end
  end

  describe '#update_status' do
    let(:pc) do
      # using create here, because if the object has never been saved, #changed? will always return true
      PreservedCopy.create(
        preserved_object_id: preserved_object.id,
        endpoint_id: endpoint.id,
        version: 0,
        status: PreservedCopy::INVALID_MOAB_STATUS,
        size: 1
      )
    end

    it 'does nothing if the status has not changed' do
      ran_the_block = false
      pc.update_status(PreservedCopy::INVALID_MOAB_STATUS) { ran_the_block = true }
      expect(pc.status).to eq PreservedCopy::INVALID_MOAB_STATUS
      expect(ran_the_block).to eq false
      expect(pc.changed?).to eq false
    end

    it 'runs the block and updates the status if the status has changed' do
      ran_the_block = false
      pc.update_status(PreservedCopy::OK_STATUS) { ran_the_block = true }
      expect(pc.status).to eq PreservedCopy::OK_STATUS
      expect(ran_the_block).to eq true
      expect(pc.changed?).to eq true
    end
  end
end
