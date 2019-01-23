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

  it { is_expected.to have_many(:zipped_moab_versions) }
  it { is_expected.to have_db_index(:endpoint_name) }
  it { is_expected.to have_and_belong_to_many(:preservation_policies) }
  it { is_expected.to validate_presence_of(:endpoint_name) }
  it { is_expected.to validate_presence_of(:delivery_class) }

  describe '.seed_from_config' do
    it 'creates an endpoints entry for each zip endpoint' do
      Settings.zip_endpoints.each do |endpoint_name, endpoint_config|
        zip_endpoint_attrs = {
          endpoint_node: endpoint_config.endpoint_node,
          storage_location: endpoint_config.storage_location,
          preservation_policies: default_pres_policies,
          delivery_class: endpoint_config.delivery_class.constantize
        }
        expect(described_class.find_by(endpoint_name: endpoint_name)).to have_attributes(zip_endpoint_attrs)
      end
    end

    it 'does not re-create records that already exist' do
      # run it a second time
      expect { described_class.seed_from_config(default_pres_policies) }
        .not_to change { described_class.pluck(:endpoint_name).sort }
        .from(%w[ibm_us_south mock_archive1 zip-endpoint])
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
      described_class.seed_from_config(default_pres_policies)
      expected_ep_names = %w[fixture_archiveTest ibm_us_south mock_archive1 zip-endpoint]
      expect(described_class.pluck(:endpoint_name).sort).to eq expected_ep_names
    end
  end

  describe '.targets' do
    let!(:alternate_pres_policy) do
      create(:preservation_policy, preservation_policy_name: 'alternate_pres_policy',
                                   archive_ttl: 666,
                                   fixity_ttl: 666)
    end

    before { create(:preserved_object, druid: druid) }

    it "returns the zip endpoints which implement the PO's pres policy" do
      zip_endpoint.preservation_policies = [PreservationPolicy.default_policy, alternate_pres_policy]
      expect(ZipEndpoint.targets(druid).pluck(:endpoint_name).sort).to eq %w[ibm_us_south mock_archive1 zip-endpoint]
      zip_endpoint.preservation_policies = [alternate_pres_policy]
      expect(ZipEndpoint.targets(druid).pluck(:endpoint_name).sort).to eq %w[ibm_us_south mock_archive1]
    end
  end

  context 'ZippedMoabVersion presence on ZipEndpoint' do
    let(:version) { 3 }
    let(:other_druid) { 'zy098xw7654' }
    let(:cm_ze_ids) { cm.zipped_moab_versions.distinct(:zip_endpoint_id).where.not(zip_endpoint_id: zip_endpoint.id).pluck(:zip_endpoint_id) }
    let!(:cm) do
      po = build(:preserved_object, current_version: version, druid: druid)
      create(:complete_moab, version: version, preserved_object: po)
    end
    let!(:cm2) do
      po = build(:preserved_object, current_version: version, druid: other_druid)
      create(:complete_moab, version: version, preserved_object: po)
    end
    let!(:eps) { ZipEndpoint.where(id: cm_ze_ids).order(:endpoint_name) }
    let!(:ep) { eps.first } # snag before ZMV destroy_all
    let!(:ep2) { eps.second }

    before { ZippedMoabVersion.destroy_all }

    describe '.which_have_archive_copy' do
      it 'returns the zip endpoints which have a complete moab for the druid version' do # rubocop:disable RSpec/MultipleExpectations
        expect(ZipEndpoint.which_have_archive_copy(druid, version).pluck(:endpoint_name)).to eq []
        expect { cm.zipped_moab_versions.create!(version: version, zip_endpoint: ep) }.not_to change {
          [
            ZipEndpoint.which_have_archive_copy(druid, version - 1).pluck(:endpoint_name),
            ZipEndpoint.which_have_archive_copy(other_druid, version).pluck(:endpoint_name),
            ZipEndpoint.which_have_archive_copy(other_druid, version - 1).pluck(:endpoint_name)
          ]
        }.from([[], [], []])
        expect(ZipEndpoint.which_have_archive_copy(druid, version).pluck(:endpoint_name)).to eq [ep.endpoint_name]

        expect { cm2.zipped_moab_versions.create!(version: version - 1, zip_endpoint: ep) }.to change {
          ZipEndpoint.which_have_archive_copy(other_druid, version - 1).pluck(:endpoint_name)
        }.from([]).to([ep.endpoint_name])

        expect { cm2.zipped_moab_versions.create!(version: version - 1, zip_endpoint: zip_endpoint) }.not_to change {
          [
            ZipEndpoint.which_have_archive_copy(druid, version).pluck(:endpoint_name),
            ZipEndpoint.which_have_archive_copy(druid, version - 1).pluck(:endpoint_name),
            ZipEndpoint.which_have_archive_copy(other_druid, version).pluck(:endpoint_name)
          ]
        }.from([[ep.endpoint_name], [], []])
        expect(ZipEndpoint.which_have_archive_copy(other_druid, version - 1).pluck(:endpoint_name).sort).to eq [ep.endpoint_name, 'zip-endpoint']
      end
    end

    describe '.which_need_archive_copy' do
      let(:names) { [ep.endpoint_name, ep2.endpoint_name, zip_endpoint.endpoint_name] }

      # rubocop:disable RSpec/MultipleExpectations
      it "returns the zip endpoints which should have a complete moab for the druid/version, but which don't yet" do
        expect(ZipEndpoint.which_need_archive_copy(druid, version).pluck(:endpoint_name).sort).to eq names
        expect(ZipEndpoint.which_need_archive_copy(druid, version - 1).pluck(:endpoint_name).sort).to eq names
        expect(ZipEndpoint.which_need_archive_copy(other_druid, version).pluck(:endpoint_name).sort).to eq names
        expect(ZipEndpoint.which_need_archive_copy(other_druid, version - 1).pluck(:endpoint_name).sort).to eq names

        cm.zipped_moab_versions.create!(version: version, zip_endpoint: ep)
        expect(ZipEndpoint.which_need_archive_copy(druid, version).pluck(:endpoint_name)).to eq %w[mock_archive1 zip-endpoint]
        expect(ZipEndpoint.which_need_archive_copy(druid, version - 1).pluck(:endpoint_name).sort).to eq names
        expect(ZipEndpoint.which_need_archive_copy(other_druid, version).pluck(:endpoint_name).sort).to eq names
        expect(ZipEndpoint.which_need_archive_copy(other_druid, version - 1).pluck(:endpoint_name).sort).to eq names

        cm2.zipped_moab_versions.create!(version: version - 1, zip_endpoint: ep)
        expect(ZipEndpoint.which_need_archive_copy(druid, version).pluck(:endpoint_name)).to eq %w[mock_archive1 zip-endpoint]
        expect(ZipEndpoint.which_need_archive_copy(druid, version - 1).pluck(:endpoint_name).sort).to eq names
        expect(ZipEndpoint.which_need_archive_copy(other_druid, version).pluck(:endpoint_name).sort).to eq names
        expect(ZipEndpoint.which_need_archive_copy(other_druid, version - 1).pluck(:endpoint_name)).to eq %w[mock_archive1 zip-endpoint]
      end
      # rubocop:enable RSpec/MultipleExpectations
    end
  end
end
