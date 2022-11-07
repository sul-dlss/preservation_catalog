# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DashboardReplicationHelper do
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
        expect(helper.replication_ok?).to be false
      end
    end

    context 'when ZipEndpoint counts match num_object_versions_per_preserved_object' do
      before do
        # test seeds have 2 ZipEndpoints
        create(:zipped_moab_version, preserved_object: po1, version: 2, zip_endpoint: ZipEndpoint.first)
        create(:zipped_moab_version, preserved_object: po1, version: 2, zip_endpoint: ZipEndpoint.last)
      end

      it 'returns true' do
        expect(helper.replication_ok?).to be true
      end
    end
  end

  describe '#replication_info' do
    skip('FIXME: intend to change this internal structure soon; not testing yet')
    # replication_info = {}
    # ZipEndpoint.all.each do |zip_endpoint|
    #   replication_info[zip_endpoint.endpoint_name] =
    #     [
    #       zip_endpoint.delivery_class,
    #       ZippedMoabVersion.where(zip_endpoint_id: zip_endpoint.id).count
    #     ].flatten
    # end
    # replication_info
  end

  describe '#zip_part_suffixes' do
    before do
      create(:zip_part, size: 1 * Numeric::TERABYTE)
      create(:zip_part, size: (2 * Numeric::TERABYTE))
      create(:zip_part, size: (3 * Numeric::TERABYTE))
    end

    it 'returns a hash of suffies as keys and values as counts' do
      expect(helper.zip_part_suffixes).to eq('.zip' => 3)
    end
  end

  describe '#zip_parts_total_size' do
    before do
      create(:zip_part, size: 1 * Numeric::TERABYTE)
      create(:zip_part, size: ((2 * Numeric::TERABYTE) + (500 * Numeric::GIGABYTE)))
      create(:zip_part, size: (3 * Numeric::TERABYTE))
    end

    it 'returns the total size of ZipParts in Terabytes as a string' do
      expect(helper.zip_parts_total_size).to eq '6.49 Tb'
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
      expect(helper.num_replication_errors).to eq 3
    end
  end
end
