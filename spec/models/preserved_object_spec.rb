require 'rails_helper'

RSpec.describe PreservedObject, type: :model do
  let!(:preservation_policy) { PreservationPolicy.default_policy }

  let(:required_attributes) do
    {
      druid: 'ab123cd4567',
      current_version: 1,
      preservation_policy: preservation_policy
    }
  end

  it { is_expected.to belong_to(:preservation_policy) }
  it { is_expected.to have_many(:preserved_copies) }
  it { is_expected.to have_db_index(:druid) }
  it { is_expected.to have_db_index(:preservation_policy_id) }
  it { is_expected.to validate_presence_of(:druid) }
  it { is_expected.to validate_presence_of(:current_version) }

  context 'validation' do
    it 'is valid with required attributes' do
      expect(described_class.new(required_attributes)).to be_valid
    end
    it 'is not valid without all required attributes' do
      expect(described_class.new).not_to be_valid
      expect(described_class.new(current_version: 1)).not_to be_valid
    end
    it 'with bad druid is invalid' do
      expect(described_class.new(required_attributes.merge(druid: 'FOObarzubaz'))).not_to be_valid
      expect(described_class.new(required_attributes.merge(druid: 'b123cd4567'))).not_to be_valid
      expect(described_class.new(required_attributes.merge(druid: 'ab123cd45678'))).not_to be_valid
    end
    it 'with druid prefix is invalid' do
      expect(described_class.new(required_attributes.merge(druid: 'druid:ab123cd4567'))).not_to be_valid
      expect(described_class.new(required_attributes.merge(druid: 'DRUID:ab123cd4567'))).not_to be_valid
    end

    describe 'enforces unique constraint on druid' do
      before { described_class.create!(required_attributes) }

      it 'at model level' do
        msg = 'Validation failed: Druid has already been taken'
        expect { described_class.create!(required_attributes) }.to raise_error(ActiveRecord::RecordInvalid, msg)
      end
      it 'at db level' do
        dup_po = described_class.new(druid: 'ab123cd4567', current_version: 2, preservation_policy: preservation_policy)
        expect { dup_po.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe '#create_archive_preserved_copies' do
    let(:druid) { 'ab123cd4567' }
    let(:current_version) { 3 }
    let!(:po) { create(:preserved_object, druid: druid, current_version: current_version) }
    let(:archive_ep) { Endpoint.find_by(endpoint_name: 'mock_archive1') }
    let(:new_archive_ep) { create(:archive_endpoint, endpoint_name: 'mock_archive2') }
    let(:archive_pcs_for_druid) do
      PreservedCopy
        .joins(endpoint: [:endpoint_type])
        .where(preserved_object: po, endpoint_types: { endpoint_class: 'archive' })
    end

    it "creates pres copies that don't yet exist for the given version, but should" do
      expect { po.create_archive_preserved_copies(current_version) }.to change {
        Endpoint.which_need_archive_copy(druid, current_version).to_a
      }.from([archive_ep]).to([])

      expect(archive_pcs_for_druid.count).to eq 1

      expect { po.create_archive_preserved_copies(current_version - 1) }.to change {
        Endpoint.which_need_archive_copy(druid, current_version - 1).to_a
      }.from([archive_ep]).to([])
      expect(archive_pcs_for_druid.count).to eq 2

      expect(archive_pcs_for_druid.where(version: 1).count).to eq 0
    end

    it 'creates the pres copies so that they start with UNREPLICATED_STATUS' do
      expect(po.create_archive_preserved_copies(current_version).all?(&:unreplicated?)).to be true
    end

    it "creates pres copies that don't yet exist for the given endpoint, but should" do
      expect { po.create_archive_preserved_copies(current_version) }.to change {
        Endpoint.which_need_archive_copy(druid, current_version).to_a
      }.from([archive_ep]).to([])
      expect(archive_pcs_for_druid.where(version: current_version).count).to eq 1

      new_archive_ep.preservation_policies = [PreservationPolicy.default_policy]
      expect { po.create_archive_preserved_copies(current_version) }.to change {
        Endpoint.which_need_archive_copy(druid, current_version).to_a
      }.from([new_archive_ep]).to([])
      expect(archive_pcs_for_druid.where(version: current_version).count).to eq 2
    end

    it 'checks that version is in range' do
      [-1, 0, 4, 5].each do |version|
        exp_err_msg = "archive_vers (#{version}) must be between 0 and current_version (#{current_version})"
        expect { po.create_archive_preserved_copies(version) }.to raise_error ArgumentError, exp_err_msg
      end

      (1..3).each do |version|
        expect { po.create_archive_preserved_copies(version) }.not_to raise_error
      end
    end

    it 'creates the pres copies in a transaction and allows exceptions to bubble up' do
      new_archive_ep.preservation_policies = [PreservationPolicy.default_policy]
      allow(PreservedCopy).to receive(:create!).with(
        preserved_object: po,
        version: current_version,
        endpoint: new_archive_ep,
        status: PreservedCopy::UNREPLICATED_STATUS
      ).and_raise(ActiveRecord::ConnectionTimeoutError)

      # would do `expect { }.not_to(change { })`, but the raised error doesn't play nicely with that construct
      exp_ep_list = %w[mock_archive1 mock_archive2]
      expect(Endpoint.which_need_archive_copy(druid, current_version).pluck(:endpoint_name).sort).to eq exp_ep_list
      expect do
        po.create_archive_preserved_copies(current_version)
      end.to raise_error(ActiveRecord::ConnectionTimeoutError)
      expect(Endpoint.which_need_archive_copy(druid, current_version).pluck(:endpoint_name).sort).to eq exp_ep_list
    end
  end
end
