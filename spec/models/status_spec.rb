require 'rails_helper'

RSpec.describe Status, type: :model do
  let!(:status) { Status.default_status }

  it 'is valid with valid attributes' do
    expect(status).to be_valid
  end

  it 'is not valid without valid attributes' do
    expect(Status.new).not_to be_valid
  end

  it 'enforces unique constraint on status_text (model level)' do
    status
    exp_err_msg = 'Validation failed: Status text has already been taken'
    expect do
      Status.create!(status_text: 'ok')
    end.to raise_error(ActiveRecord::RecordInvalid, exp_err_msg)
  end

  it 'enforces unique constraint on status_text (db level)' do
    status
    dup_status = Status.new
    dup_status.status_text = 'ok'
    expect { dup_status.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it { is_expected.to have_many(:preserved_copies) }
  it { is_expected.to have_db_index(:status_text) }

  describe '.seed_from_config' do
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

  describe '.default_status' do
    it 'returns the default status object' do
      # db already seeded
      expect(Status.default_status).to be_a_kind_of Status
    end

    it "raises RecordNotFound if the default status doesn't exist in the db" do
      # a bit contrived, but just want to test that lack of default Status causes lookup to
      # fail fast.  since db is already seeded, we just make it look up something that we know isn't there.
      allow(Settings).to receive(:default_status).and_return('nonexistent')
      expect { Status.default_status }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '.unexpected_version' do
    it 'returns a Status object' do
      expect(Status.unexpected_version).to be_a_kind_of Status
    end
  end

  describe '.ok' do
    it 'returns a Status object' do
      expect(Status.ok).to be_a_kind_of Status
    end
  end
end
