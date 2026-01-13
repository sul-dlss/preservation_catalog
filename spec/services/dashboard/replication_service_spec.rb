# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::ReplicationService do
  let(:outer_class) do
    Class.new do
      include Dashboard::ReplicationService
    end
  end

  describe '#replication_and_zipped_moab_versions_ok?' do
    let(:test_class) { outer_class.new }

    context 'when replication_ok? is false' do
      before do
        allow(test_class).to receive(:replication_ok?).and_return(false)
      end

      it 'returns false' do
        expect(test_class.replication_and_zipped_moab_versions_ok?).to be false
      end
    end

    context 'when !zipped_moab_versions_failed? is true' do
      before do
        allow(test_class).to receive(:zipped_moab_versions_failed?).and_return(true)
      end

      it 'returns false' do
        expect(test_class.replication_and_zipped_moab_versions_ok?).to be false
      end
    end

    context 'when replication_ok? is true and zipped_moab_versions_failed? is false' do
      before do
        allow(test_class).to receive_messages(replication_ok?: true, zipped_moab_versions_failed?: false)
      end

      it 'returns true' do
        expect(test_class.replication_and_zipped_moab_versions_ok?).to be true
      end
    end
  end

  describe '#replication_ok?' do
    let(:po1) { create(:preserved_object, current_version: 2) }
    let(:po2) { create(:preserved_object, current_version: 1) }

    before do
      # test seeds are on each ZipEndpoint
      ZipEndpoint.find_each do |zip_endpoint|
        create(:zipped_moab_version, preserved_object: po1, zip_endpoint: zip_endpoint)
        create(:zipped_moab_version, preserved_object: po2, zip_endpoint: zip_endpoint)
      end
    end

    context 'when a ZipEndpoint count does not match num_object_versions_per_preserved_object' do
      it 'returns false' do
        expect(outer_class.new.replication_ok?).to be false
      end
    end

    context 'when ZipEndpoint counts match num_object_versions_per_preserved_object' do
      before do
        # test seeds are on each ZipEndpoint
        ZipEndpoint.find_each do |zip_endpoint|
          create(:zipped_moab_version, preserved_object: po1, version: 2, zip_endpoint: zip_endpoint)
        end
      end

      it 'returns true' do
        expect(outer_class.new.replication_ok?).to be true
      end
    end
  end

  describe '#endpoint_replication_count_ok?' do
    before do
      create(:preserved_object, current_version: 2)
      create(:preserved_object, current_version: 3)
    end

    context 'when parameter matches num_object_versions_per_preserved_object' do
      it 'returns true' do
        expect(outer_class.new.endpoint_replication_count_ok?(5)).to be true
      end
    end

    context 'when parameter does not match num_object_versions_per_preserved_object' do
      it 'returns false' do
        expect(outer_class.new.endpoint_replication_count_ok?(4)).to be false
      end
    end
  end

  describe '#endpoint_data' do
    let(:endpoint1) { ZipEndpoint.first }
    let(:endpoint2) { ZipEndpoint.last }

    before do
      5.times { create(:zipped_moab_version, zip_endpoint: endpoint1) }
      2.times { create(:zipped_moab_version, zip_endpoint: endpoint2) }
    end

    it 'returns a hash with endpoint_name keys and values of Hash with delivery_class and replication_count' do
      endpoint_data = outer_class.new.endpoint_data
      expect(endpoint_data[endpoint1.endpoint_name]).to eq({ replication_count: 5 })
      expect(endpoint_data[endpoint2.endpoint_name]).to eq({ replication_count: 2 })
    end
  end

  describe '#zipped_moab_versions_failed_count' do
    before do
      create(:zipped_moab_version, status: 'incomplete')
      create_list(:zipped_moab_version, 2, status: 'ok')
      create_list(:zipped_moab_version, 2, status: 'failed')
    end

    it 'returns count of failed ZippedMoabVersions' do
      expect(ZippedMoabVersion.count).to eq 5
      expect(outer_class.new.zipped_moab_versions_failed_count).to eq 2
    end
  end

  describe '#zipped_moab_versions_failed?' do
    before do
      create(:zipped_moab_version, status: 'ok')
    end

    context 'when no failed ZippedMoabVersions' do
      it 'returns false' do
        expect(outer_class.new.zipped_moab_versions_failed?).to be false
      end
    end

    context 'when failed ZippedMoabVersions' do
      before do
        create(:zipped_moab_version, status: 'failed')
      end

      it 'returns true' do
        expect(outer_class.new.zipped_moab_versions_failed?).to be true
      end
    end
  end

  describe '#zipped_moab_versions_incomplete?' do
    context 'when no incomplete ZippedMoabVersions' do
      it 'returns false' do
        expect(outer_class.new.zipped_moab_versions_incomplete?).to be false
      end
    end

    context 'when at least one ZippedMoabVersion has status incomplete' do
      before do
        create(:zipped_moab_version, status: 'incomplete')
      end

      it 'returns true' do
        expect(outer_class.new.zipped_moab_versions_incomplete?).to be true
      end
    end
  end
end
