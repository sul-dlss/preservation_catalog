require 'rails_helper'

RSpec.describe ZipEndpoint, type: :model do
  let(:default_pres_policies) { [PreservationPolicy.default_policy] }
  let(:druid) { 'ab123cd4567' }
  let!(:zip_endpoint) { create(:zip_endpoint, endpoint_name: 'zip-endpoint', endpoint_node: 'us-west-01') }

  it 'is not valid unless it has all required attributes' do
    expect(described_class.new(delivery_class: 1)).not_to be_valid
    expect(described_class.new(endpoint_name: 'aws')).not_to be_valid
    expect(zip_endpoint).to be_valid
  end

  it 'enforces unique constraint on endpoint_name (model level)' do
    expect do
      described_class.create!(endpoint_name: 'zip-endpoint', delivery_class: S3EastDeliveryJob)
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'enforces unique constraint on endpoint_name (db level)' do
    expect do
      described_class.new(endpoint_name: 'zip-endpoint', delivery_class: 1).save(validate: false)
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'has multiple delivery_classes' do
    expect(described_class.delivery_classes).to include(S3WestDeliveryJob, S3EastDeliveryJob)
  end

  it { is_expected.to have_many(:archive_preserved_copies) }
  it { is_expected.to have_db_index(:endpoint_name) }
  it { is_expected.to have_and_belong_to_many(:preservation_policies) }
  it { is_expected.to validate_presence_of(:endpoint_name) }
  it { is_expected.to validate_presence_of(:delivery_class) }

  describe '.seed_zip_endpoints_from_config' do
    it 'creates an endpoints entry for each zip endpoint' do
      Settings.zip_endpoints.each do |endpoint_name, endpoint_config|
        zip_endpoint_attrs = {
          endpoint_node: endpoint_config.endpoint_node,
          storage_location: endpoint_config.storage_location,
          preservation_policies: default_pres_policies,
          delivery_class: S3WestDeliveryJob
        }
        expect(described_class.find_by(endpoint_name: endpoint_name)).to have_attributes(zip_endpoint_attrs)
      end
    end

    it 'does not re-create records that already exist' do
      # run it a second time
      expect { described_class.seed_zip_endpoints_from_config(default_pres_policies) }
        .not_to change { described_class.pluck(:endpoint_name).sort }
        .from(%w[mock_archive1 zip-endpoint])
    end

    it 'adds new records if there are additions to Settings since the last run' do
      zip_endpoints_setting = Config::Options.new(
        fixture_archiveTest:
          Config::Options.new(
            endpoint_node: 'endpoint_node',
            storage_location: 'storage_location',
            delivery_class: 'S3WestDeliveryJob'
          )
      )
      allow(Settings).to receive(:zip_endpoints).and_return(zip_endpoints_setting)

      # run it a second time
      described_class.seed_zip_endpoints_from_config(default_pres_policies)
      expected_ep_names = %w[fixture_archiveTest mock_archive1 zip-endpoint]
      expect(described_class.pluck(:endpoint_name).sort).to eq expected_ep_names
    end
  end

  describe '.archive_targets' do
    let!(:alternate_pres_policy) do
      PreservationPolicy.create!(preservation_policy_name: 'alternate_pres_policy',
                                 archive_ttl: 666,
                                 fixity_ttl: 666)
    end

    before { create(:preserved_object, druid: druid) }

    it "returns the archive endpoints which implement the PO's pres policy" do
      archive_endpoint.preservation_policies = [PreservationPolicy.default_policy, alternate_pres_policy]
      expect(ArchiveEndpoint.archive_targets(druid).pluck(:endpoint_name)).to eq %w[archive-endpoint mock_archive1]
      archive_endpoint.preservation_policies = [alternate_pres_policy]
      expect(ArchiveEndpoint.archive_targets(druid).pluck(:endpoint_name)).to eq %w[mock_archive1]
    end
  end

  context 'ArchivePreservedCopy presence on ArchiveEndpoint' do
    let(:version) { 3 }
    let!(:po) { create(:preserved_object, current_version: version, druid: druid) }
    let(:pc) { create(:preserved_copy, preserved_object: po) }
    let(:other_druid) { 'zy098xw7654' }
    let!(:pc_other_druid) do
      other_po = create(:preserved_object, current_version: version, druid: other_druid)
      create(:preserved_copy, version: version, preserved_object: other_po)
    end
    let(:ma1_ep) { ArchiveEndpoint.find_by!(endpoint_name: 'mock_archive1') }

    describe '.which_have_archive_copy' do
      it 'returns the archive endpoints which have a pres copy for the druid version' do
        expect(ArchiveEndpoint.which_have_archive_copy(druid, version).pluck(:endpoint_name)).to eq []
        expect(ArchiveEndpoint.which_have_archive_copy(druid, version - 1).pluck(:endpoint_name)).to eq []
        expect(ArchiveEndpoint.which_have_archive_copy(other_druid, version).pluck(:endpoint_name)).to eq []
        expect(ArchiveEndpoint.which_have_archive_copy(other_druid, version - 1).pluck(:endpoint_name)).to eq []

        create(:archive_preserved_copy, preserved_copy: pc, version: version, archive_endpoint: ma1_ep)
        expect(ArchiveEndpoint.which_have_archive_copy(druid, version).pluck(:endpoint_name)).to eq %w[mock_archive1]
        expect(ArchiveEndpoint.which_have_archive_copy(druid, version - 1).pluck(:endpoint_name)).to eq []
        expect(ArchiveEndpoint.which_have_archive_copy(other_druid, version).pluck(:endpoint_name)).to eq []
        expect(ArchiveEndpoint.which_have_archive_copy(other_druid, version - 1).pluck(:endpoint_name)).to eq []

        create(:archive_preserved_copy, preserved_copy: pc_other_druid, version: version - 1, archive_endpoint: ma1_ep)
        expect(ArchiveEndpoint.which_have_archive_copy(druid, version).pluck(:endpoint_name)).to eq %w[mock_archive1]
        expect(ArchiveEndpoint.which_have_archive_copy(druid, version - 1).pluck(:endpoint_name)).to eq []
        expect(ArchiveEndpoint.which_have_archive_copy(other_druid, version).pluck(:endpoint_name)).to eq []
        expect(ArchiveEndpoint.which_have_archive_copy(other_druid, version - 1).pluck(:endpoint_name)).to eq %w[mock_archive1]

        create(:archive_preserved_copy, preserved_copy: pc_other_druid, version: version - 1, archive_endpoint: archive_endpoint)
        expect(ArchiveEndpoint.which_have_archive_copy(druid, version).pluck(:endpoint_name)).to eq %w[mock_archive1]
        expect(ArchiveEndpoint.which_have_archive_copy(druid, version - 1).pluck(:endpoint_name)).to eq []
        expect(ArchiveEndpoint.which_have_archive_copy(other_druid, version).pluck(:endpoint_name)).to eq []
        expect(ArchiveEndpoint.which_have_archive_copy(other_druid, version - 1).pluck(:endpoint_name).sort).to eq %w[archive-endpoint mock_archive1]
      end
    end

    describe '.which_need_archive_copy' do
      it "returns the archive endpoints which should have a pres copy for the druid/version, but which don't yet" do
        expect(ArchiveEndpoint.which_need_archive_copy(druid, version).pluck(:endpoint_name).sort).to eq %w[archive-endpoint mock_archive1]
        expect(ArchiveEndpoint.which_need_archive_copy(druid, version - 1).pluck(:endpoint_name).sort).to eq %w[archive-endpoint mock_archive1]
        expect(ArchiveEndpoint.which_need_archive_copy(other_druid, version).pluck(:endpoint_name).sort).to eq %w[archive-endpoint mock_archive1]
        expect(ArchiveEndpoint.which_need_archive_copy(other_druid, version - 1).pluck(:endpoint_name).sort).to eq %w[archive-endpoint mock_archive1]

        create(:archive_preserved_copy, preserved_copy: pc, version: version, archive_endpoint: ma1_ep)
        expect(ArchiveEndpoint.which_need_archive_copy(druid, version).pluck(:endpoint_name)).to eq %w[archive-endpoint]
        expect(ArchiveEndpoint.which_need_archive_copy(druid, version - 1).pluck(:endpoint_name).sort).to eq %w[archive-endpoint mock_archive1]
        expect(ArchiveEndpoint.which_need_archive_copy(other_druid, version).pluck(:endpoint_name).sort).to eq %w[archive-endpoint mock_archive1]
        expect(ArchiveEndpoint.which_need_archive_copy(other_druid, version - 1).pluck(:endpoint_name).sort).to eq %w[archive-endpoint mock_archive1]

        create(:archive_preserved_copy, preserved_copy: pc_other_druid, version: version - 1, archive_endpoint: ma1_ep)
        expect(ArchiveEndpoint.which_need_archive_copy(druid, version).pluck(:endpoint_name)).to eq %w[archive-endpoint]
        expect(ArchiveEndpoint.which_need_archive_copy(druid, version - 1).pluck(:endpoint_name).sort).to eq %w[archive-endpoint mock_archive1]
        expect(ArchiveEndpoint.which_need_archive_copy(other_druid, version).pluck(:endpoint_name).sort).to eq %w[archive-endpoint mock_archive1]
        expect(ArchiveEndpoint.which_need_archive_copy(other_druid, version - 1).pluck(:endpoint_name)).to eq %w[archive-endpoint]
      end
    end
  end
end
