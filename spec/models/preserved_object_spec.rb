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

  describe '#expected_versions' do
    let(:po) { build(:preserved_object) }

    it 'returns range 1..current_version' do
      expect(po.expected_versions).to eq(1..1)
      po.current_version = 3
      expect(po.expected_versions).to eq(1..3)
    end
  end

  describe '#create_archive_preserved_copies!' do
    let(:po) { create(:preserved_object, druid: 'ab123cd4567', current_version: 3) }
    let(:ep) do
      create(:archive_endpoint, endpoint_name: 'ep2', preservation_policies: [PreservationPolicy.default_policy])
    end

    it "backfills missing pres copies, without duplication" do
      expect { po.create_archive_preserved_copies! }.to change { po.preserved_copies.count }.from(0).to(3)
      expect { po.create_archive_preserved_copies! }.not_to(change { po.preserved_copies.count }) # 2nd run adds none
    end

    it 'created pres copies have status "unreplicated"' do
      expect(po.create_archive_preserved_copies!).to all be_unreplicated
    end

    it "handles all archive endpoints" do
      po.preserved_copies.create!(version: 2, endpoint: ep, status: 'ok')
      pcs = []
      expect { pcs = po.create_archive_preserved_copies! }.to change { po.preserved_copies.count }.from(1).to(6)
      expect(pcs.map { |x| x.endpoint.endpoint_name }.sort).to eq %w[ep2 ep2 mock_archive1 mock_archive1 mock_archive1]
      expect(pcs.map(&:version).sort).to eq [1, 1, 2, 3, 3]
      expect(po.preserved_copies.count).to eq 6
    end
  end
end
