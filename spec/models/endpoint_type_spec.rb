require 'rails_helper'

RSpec.describe EndpointType, type: :model do
  let(:test_type_name) { 'unit_test_nfs' }

  it 'is valid with valid attributes' do
    endpoint_type = EndpointType.create!(type_name: test_type_name, endpoint_class: 'online')
    expect(endpoint_type).to be_valid
  end

  it 'is not valid without valid attributes' do
    expect(EndpointType.new).not_to be_valid
  end

  it 'enforces unique constraint on type_name' do
    expect do
      EndpointType.create!(type_name: test_type_name, endpoint_class: 'online')
      EndpointType.create!(type_name: test_type_name, endpoint_class: 'online')
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it { is_expected.to validate_presence_of(:type_name) }
  it { is_expected.to validate_presence_of(:endpoint_class) }
  it { is_expected.to have_many(:endpoints) }

  describe '.seed_from_config' do
    it 'creates the endpoint types listed in Settings' do
      Settings.endpoint_types.each do |type_name, type_config|
        expect(EndpointType.find_by(type_name: type_name.to_s).endpoint_class).to eq type_config.endpoint_class
      end
    end

    it 'does not re-create records that already exist' do
      # run it a second time
      EndpointType.seed_from_config
      # sort so we can avoid comparing via include, and see that it has only/exactly the expected elements
      expect(EndpointType.pluck(:type_name).sort).to eq %w[aws_s3 online_nfs]
    end

    it 'adds new records if there are additions to Settings since the last run' do
      archive_endpoint_setting = Config::Options.new(
        some_archive_endpoint_type: Config::Options.new(endpoint_class: 'archive')
      )
      allow(Settings).to receive(:endpoint_types).and_return(archive_endpoint_setting)

      # run it a second time
      EndpointType.seed_from_config
      expect(EndpointType.find_by(type_name: 'some_archive_endpoint_type')).to be_a_kind_of EndpointType
    end
  end
end
