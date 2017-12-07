require 'rails_helper'

RSpec.describe PreservationPolicy, type: :model do
  it 'is valid with valid attributes' do
    preservation_policy = PreservationPolicy.find_by(preservation_policy_name: 'default')
    expect(preservation_policy).to be_valid
  end

  it 'is not valid without valid attributes' do
    expect(PreservationPolicy.new).not_to be_valid
  end

  it 'enforces unique constraint on preservation_policy_name (model level)' do
    exp_err_msg = 'Validation failed: Preservation policy name has already been taken'
    expect do
      PreservationPolicy.create!(preservation_policy_name: 'default',
                                 archive_ttl: 666,
                                 fixity_ttl: 666)
    end.to raise_error(ActiveRecord::RecordInvalid, exp_err_msg)
  end

  it 'enforces unique constraint on preservation_policy_name (db level)' do
    dup_preservation_policy = PreservationPolicy.new(preservation_policy_name: 'default',
                                                     archive_ttl: 666,
                                                     fixity_ttl: 666)
    expect { dup_preservation_policy.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it { is_expected.to have_many(:preserved_objects) }
  it { is_expected.to have_and_belong_to_many(:endpoints) }

  describe '.seed_from_config' do
    it 'creates the preservation policies listed in Settings' do
      # db already seeded
      Settings.preservation_policies.policy_definitions.each_key do |policy_name|
        expect(
          PreservationPolicy.find_by(preservation_policy_name: policy_name.to_s)
        ).to be_a_kind_of PreservationPolicy
      end
    end

    it 'does not re-create records that already exist' do
      # db already seeded
      PreservationPolicy.seed_from_config
      expect(PreservationPolicy.pluck(:preservation_policy_name)).to eq %w[default]
    end

    it 'adds new records if there are additions to Settings since the last run' do
      # db already seeded
      archive_pres_policy_setting = Config::Options.new(
        archive_policy: Config::Options.new(archive_ttl: 666, fixity_ttl: 666)
      )
      allow(Settings.preservation_policies).to receive(:policy_definitions).and_return(archive_pres_policy_setting)
      PreservationPolicy.seed_from_config
      expect(PreservationPolicy.find_by(preservation_policy_name: 'archive_policy')).to be_a_kind_of PreservationPolicy
    end
  end

  describe '.default_policy' do
    it 'returns the default preservation policy object' do
      # db already seeded
      expect(PreservationPolicy.default_policy).to be_a_kind_of PreservationPolicy
    end

    it "raises RecordNotFound if the default policy doesn't exist in the db" do
      # a bit contrived, but just want to test that lack of default PreservationPolicy causes lookup to
      # fail fast.  since db is already seeded, we just make it look up something that we know isn't there.
      allow(Settings.preservation_policies).to receive(:default_policy_name).and_return('nonexistent')
      expect { PreservationPolicy.default_policy }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '.default_policy_id' do
    # clear the cache before each test to reset
    before { PreservationPolicy.send(:clear_id_cache) }

    # clear the cache once more before we leave, to clean up, because
    # rspec is going to auto-rollback the pres policy one test creates,
    # and our Settings change was totally ephemeral
    after(:all) { PreservationPolicy.send(:clear_id_cache) }

    it 'returns the default preservation policy id' do
      expect(PreservationPolicy.default_policy_id).to eq PreservationPolicy.default_policy.id
    end

    it "doesn't re-run the query if a cached value is available" do
      expect(PreservationPolicy).to receive(:find_by!).once.and_call_original
      PreservationPolicy.default_policy_id
      PreservationPolicy.default_policy_id
    end

    it 'clears the cache and looks up fresh values after an event that might make cached values stale' do
      expect(PreservationPolicy).to receive(:find_by!).twice.and_call_original

      # first lookup, gets cached
      PreservationPolicy.default_policy_id

      # pretend we added a new pres policy to settings and re-seeded and now it's the default
      new_default_pres_policy = PreservationPolicy.create!(preservation_policy_name: 'new_default',
                                                           archive_ttl: 666,
                                                           fixity_ttl: 666)
      new_default_setting = Config::Options.new(default_policy_name: 'new_default')
      allow(Settings).to receive(:preservation_policies).and_return(new_default_setting)

      # make sure the cached value reflects the change
      expect(new_default_pres_policy.id).to eq PreservationPolicy.default_policy_id

      # here we call it a third time, but there were no changes since we last called, so call twice expectation
      # at start of test should be satisfied
      PreservationPolicy.default_policy_id
    end
  end
end
