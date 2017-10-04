require 'rails_helper'

RSpec.describe PreservationPolicy, type: :model do
  it 'is valid with valid attributes' do
    preservation_policy = PreservationPolicy.create!(preservation_policy_name: 'default',
                                                     archive_ttl: 604_800,
                                                     fixity_ttl: 604_800)
    expect(preservation_policy).to be_valid
  end

  it 'is not valid without valid attributes' do
    expect(PreservationPolicy.new).not_to be_valid
  end

  it { is_expected.to have_many(:preserved_objects) }
  it { is_expected.to have_and_belong_to_many(:endpoints) }

  describe '.seed_from_config' do
    it 'creates the preservation policies listed in Settings' do
      PreservationPolicy.seed_from_config
      Settings.preservation_policies.policy_definitions.each do |policy_name, _policy_config|
        expect(
          PreservationPolicy.find_by(preservation_policy_name: policy_name.to_s)
        ).to be_a_kind_of PreservationPolicy
      end
    end

    it 'does not re-create records that already exist' do
      PreservationPolicy.seed_from_config
      PreservationPolicy.seed_from_config
      expect(PreservationPolicy.pluck(:preservation_policy_name)).to eq %w[default]
    end

    it 'adds new records if there are additions to Settings since the last run' do
      PreservationPolicy.seed_from_config
      archive_pres_policy_setting = Config::Options.new(
        archive_policy: Config::Options.new(archive_ttl: 604_800, fixity_ttl: 604_800)
      )
      allow(Settings.preservation_policies).to receive(:policy_definitions).and_return(archive_pres_policy_setting)
      PreservationPolicy.seed_from_config
      expect(PreservationPolicy.find_by(preservation_policy_name: 'archive_policy')).to be_a_kind_of PreservationPolicy
    end
  end

  describe '.default_preservation_policy' do
    it 'returns the default preservation policy object' do
      PreservationPolicy.seed_from_config
      expect(PreservationPolicy.default_preservation_policy).to be_a_kind_of PreservationPolicy
    end

    it "raises RecordNotFound if the default policy doesn't exist in the db" do
      expect { PreservationPolicy.default_preservation_policy }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
