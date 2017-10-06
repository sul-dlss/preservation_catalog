require 'rails_helper'

RSpec.describe PreservedObject, type: :model do
  let!(:preservation_policy) do
    PreservationPolicy.create!(preservation_policy_name: 'default',
                               archive_ttl: 604_800,
                               fixity_ttl: 604_800)
  end

  let(:required_attributes) do
    {
      druid: 'ab123cd4567',
      current_version: 1,
      preservation_policy: preservation_policy
    }
  end
  let(:addl_attributes) do
    {
      size: 1
    }
  end

  it { is_expected.to belong_to(:preservation_policy) }
  it { is_expected.to have_many(:preservation_copies) }
  it { is_expected.to have_db_index(:druid) }
  it { is_expected.to have_db_index(:preservation_policy_id) }

  context 'validation' do
    it 'is valid with required attributes' do
      po = PreservedObject.create(required_attributes)
      expect(po).to be_valid
    end
    it 'is valid with required and optional attributes' do
      po = PreservedObject.create(required_attributes.merge(addl_attributes))
      expect(po).to be_valid
    end
    it 'is not valid without attributes' do
      expect(PreservedObject.new).not_to be_valid
    end
    it 'is not valid without a druid' do
      expect(PreservedObject.new(current_version: 1)).not_to be_valid
    end
    it 'is not valid without a current_version' do
      expect(PreservedObject.new(druid: 'ab123cd45678')).not_to be_valid
    end
    it 'enforces unique constraint on druid (model level)' do
      PreservedObject.create(required_attributes)
      exp_err_msg = 'Validation failed: Druid has already been taken'
      expect do
        PreservedObject.create!(required_attributes)
      end.to raise_error(ActiveRecord::RecordInvalid, exp_err_msg)
    end
    it 'enforces unique constraint on druid (db level)' do
      PreservedObject.create(required_attributes)
      dup_po = PreservedObject.new
      dup_po.druid = 'ab123cd4567'
      dup_po.current_version = 2
      dup_po.preservation_policy = preservation_policy
      expect { dup_po.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
