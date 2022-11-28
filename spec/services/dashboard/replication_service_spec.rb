# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::ReplicationService do
  let(:outer_class) do
    Class.new do
      include Dashboard::ReplicationService
    end
  end

  describe '#replication_ok?' do
    let(:po1) { create(:preserved_object, current_version: 2) }
    let(:po2) { create(:preserved_object, current_version: 1) }

    before do
      # test seeds have 2 ZipEndpoints
      create(:zipped_moab_version, preserved_object: po1, zip_endpoint: ZipEndpoint.first)
      create(:zipped_moab_version, preserved_object: po1, zip_endpoint: ZipEndpoint.last)
      create(:zipped_moab_version, preserved_object: po2, zip_endpoint: ZipEndpoint.first)
      create(:zipped_moab_version, preserved_object: po2, zip_endpoint: ZipEndpoint.last)
    end

    context 'when a ZipEndpoint count does not match num_object_versions_per_preserved_object' do
      it 'returns false' do
        expect(outer_class.new.replication_ok?).to be false
      end
    end

    context 'when ZipEndpoint counts match num_object_versions_per_preserved_object' do
      before do
        # test seeds have 2 ZipEndpoints
        create(:zipped_moab_version, preserved_object: po1, version: 2, zip_endpoint: ZipEndpoint.first)
        create(:zipped_moab_version, preserved_object: po1, version: 2, zip_endpoint: ZipEndpoint.last)
      end

      it 'returns true' do
        expect(outer_class.new.replication_ok?).to be true
      end
    end
  end

  describe '#endpoint_data' do
    let(:endpoint1) { ZipEndpoint.first }
    let(:endpoint2) { ZipEndpoint.last }

    before do
      zmv_rel1 = ZippedMoabVersion.where(zip_endpoint_id: endpoint1.id)
      zmv_rel2 = ZippedMoabVersion.where(zip_endpoint_id: endpoint2.id)
      allow(zmv_rel1).to receive(:count).and_return(5)
      allow(zmv_rel2).to receive(:count).and_return(2)
      allow(ZippedMoabVersion).to receive(:where).with(zip_endpoint_id: endpoint1.id).and_return(zmv_rel1)
      allow(ZippedMoabVersion).to receive(:where).with(zip_endpoint_id: endpoint2.id).and_return(zmv_rel2)
    end

    it 'returns a hash with endpoint_name keys and values of Hash with delivery_class and replication_count' do
      endpoint_data = outer_class.new.endpoint_data
      expect(endpoint_data[endpoint1.endpoint_name]).to eq({ delivery_class: endpoint1.delivery_class, replication_count: 5 })
      expect(endpoint_data[endpoint2.endpoint_name]).to eq({ delivery_class: endpoint2.delivery_class, replication_count: 2 })
    end
  end

  describe '#zip_part_suffixes' do
    before do
      create(:zip_part, size: 1 * Numeric::TERABYTE)
      create(:zip_part, size: (2 * Numeric::TERABYTE))
      create(:zip_part, size: (3 * Numeric::TERABYTE))
    end

    it 'returns a hash of suffies as keys and values as counts' do
      expect(outer_class.new.zip_part_suffixes).to eq('.zip' => 3)
    end
  end

  describe '#zip_parts_total_size' do
    before do
      create(:zip_part, size: 1 * Numeric::TERABYTE)
      create(:zip_part, size: ((2 * Numeric::TERABYTE) + (500 * Numeric::GIGABYTE)))
      create(:zip_part, size: (3 * Numeric::TERABYTE))
    end

    it 'returns the total size of ZipParts in Terabytes as a string' do
      expect(outer_class.new.zip_parts_total_size).to eq '6.49 TB'
    end
  end

  describe '#num_replication_errors' do
    before do
      create(:zip_part, status: 'unreplicated')
      create(:zip_part, status: 'ok')
      create(:zip_part, status: 'ok')
      create(:zip_part, status: 'replicated_checksum_mismatch')
      create(:zip_part, status: 'not_found')
    end

    it 'returns ZipPart.count - ZipPart.ok.count' do
      expect(ZipPart.count).to eq 5
      expect(outer_class.new.num_replication_errors).to eq 3
    end
  end
end
