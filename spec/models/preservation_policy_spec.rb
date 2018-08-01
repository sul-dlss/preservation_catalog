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

  describe '.seed_from_config' do
    it 'creates the preservation policies listed in Settings' do
      # db already seeded
      Settings.preservation_policies.policy_definitions.each_key do |policy_name|
        expect(
          described_class.find_by(preservation_policy_name: policy_name.to_s)
        ).to be_a_kind_of described_class
      end
    end

    it 'does not re-create records that already exist' do
      # db already seeded
      described_class.seed_from_config
      expect(described_class.pluck(:preservation_policy_name)).to eq %w[default]
    end

    it 'adds new records if there are additions to Settings since the last run' do
      # db already seeded
      archive_pres_policy_setting = Config::Options.new(
        archive_policy: Config::Options.new(archive_ttl: 666, fixity_ttl: 666)
      )
      allow(Settings.preservation_policies).to receive(:policy_definitions).and_return(archive_pres_policy_setting)
      described_class.seed_from_config
      expect(described_class.find_by(preservation_policy_name: 'archive_policy')).to be_a_kind_of described_class
    end
  end

  describe '.default_policy' do
    # clear the cache before each test (and after all) to reset
    before { described_class.default_policy = nil }

    after(:all) { described_class.default_policy = nil }

    it 'returns the default preservation policy object' do
      # db already seeded
      expect(described_class.default_policy).to be_a_kind_of described_class
    end

    it "raises RecordNotFound if the default policy doesn't exist in the db" do
      # a bit contrived, but just want to test that lack of default PreservationPolicy causes lookup to
      # fail fast.  since db is already seeded, we just make it look up something that we know isn't there.
      expect(Settings.preservation_policies).to receive(:default_policy_name).and_return('nonexistent')
      expect { described_class.default_policy }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "doesn't re-run the query if a cached value is available" do
      expect(described_class).to receive(:find_by!).once.and_call_original
      described_class.default_policy
      described_class.default_policy
    end

    it 'clears the cache and looks up fresh values after an event that might make cached values stale' do
      described_class.default_policy # first lookup, gets cached
      # pretend we added a new pres policy to settings and re-seeded and now it's the default
      new_default = described_class.create!(preservation_policy_name: 'new_default', archive_ttl: 666, fixity_ttl: 666)
      allow(Settings.preservation_policies).to receive(:default_policy_name).and_return('new_default')
      expect(described_class.default_policy.id).to eq new_default.id
    end
  end
end
