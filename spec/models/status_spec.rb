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

  describe '.seed_from_config' do
    before { Status.seed_from_config }

    it 'creates the endpoint statuses listed in Settings' do
      Settings.statuses.each do |status_text|
        expect(Status.find_by(status_text: status_text)).to be_a_kind_of Status
      end
    end

    it 'does not re-create records that already exist' do
      # run it a second time
      Status.seed_from_config
      expect(Status.pluck(:status_text).sort).to eq(
        %w[expected_version_not_found_on_disk fixity_check_failed not_found_on_disk ok]
      )
    end

    it 'adds new records if there are additions to Settings since the last run' do
      Settings.statuses << 'another_status'

      # run it a second time
      Status.seed_from_config
      expect(Status.pluck(:status_text).sort).to eq(
        %w[another_status expected_version_not_found_on_disk fixity_check_failed not_found_on_disk ok]
      )
    end
  end
end
