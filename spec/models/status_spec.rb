require 'rails_helper'

RSpec.describe Status, type: :model do
  let!(:status) { Status.create!(status_text: 'ok') }

  it 'is valid with valid attributes' do
    expect(status).to be_valid
  end

  it 'is not valid without valid attributes' do
    expect(Status.new).not_to be_valid
  end

  it { is_expected.to have_many(:preservation_copies) }
end
