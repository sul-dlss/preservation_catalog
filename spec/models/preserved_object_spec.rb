require 'rails_helper'

RSpec.describe PreservedObject, type: :model do

  let!(:preserved_object) do
    PreservedObject.create(druid: 'ab123cd45678', current_version: 1, preservation_policy: 'keepit', size: 1)
  end

  it 'is not valid without valid attribute' do
    expect(PreservedObject.new).not_to be_valid
  end

  it 'is not valid without a specified current_version' do
    expect(PreservedObject.new(druid: 'ab123cd45678', preservation_policy: 'keepit', size: 1))
  end

  it 'is valid with valid attribute' do
    expect(preserved_object).to be_valid
  end

  it 'enforces unique constraint on druid' do
    expect { PreservedObject.create!(druid: 'ab123cd45678') }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it { is_expected.to have_many(:preservation_copies) }
  it { is_expected.to have_db_index(:druid) }
  it { is_expected.to have_db_index(:preservation_policy) }
end
