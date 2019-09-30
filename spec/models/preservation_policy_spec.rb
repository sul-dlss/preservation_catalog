# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PreservationPolicy, type: :model do
  it 'is valid with valid attributes' do
    preservation_policy = described_class.find_by(preservation_policy_name: 'default')
    expect(preservation_policy).to be_valid
  end

  it 'is not valid without valid attributes' do
    expect(described_class.new).not_to be_valid
  end

  it 'enforces unique constraint on preservation_policy_name (model level)' do
    exp_err_msg = 'Validation failed: Preservation policy name has already been taken'
    expect do
      described_class.create!(preservation_policy_name: 'default', archive_ttl: 666, fixity_ttl: 666)
    end.to raise_error(ActiveRecord::RecordInvalid, exp_err_msg)
  end

  it 'enforces unique constraint on preservation_policy_name (db level)' do
    dup_preservation_policy = described_class.new(preservation_policy_name: 'default',
                                                  archive_ttl: 666,
                                                  fixity_ttl: 666)
    expect { dup_preservation_policy.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it { is_expected.to have_many(:preserved_objects) }
  it { is_expected.to have_and_belong_to_many(:moab_storage_roots) }
  it { is_expected.to validate_presence_of(:preservation_policy_name) }
  it { is_expected.to validate_presence_of(:archive_ttl) }
  it { is_expected.to validate_presence_of(:fixity_ttl) }

  describe '.default_policy' do
    it 'returns the default preservation policy object' do
      expect(described_class.default_policy).to be_a(described_class)
      expect(described_class.default_policy.preservation_policy_name).to eq 'default'
    end

    it 'creates record if needed' do
      allow(described_class).to receive(:default_name).and_return('brandnew')
      expect { described_class.default_policy }.to change(described_class, :count).by(1)
    end
  end
end
