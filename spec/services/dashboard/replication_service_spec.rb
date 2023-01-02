# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::ReplicationService do
  let(:outer_class) do
    Class.new do
      include Dashboard::ReplicationService
    end
  end

  describe '#replication_and_zip_parts_ok?' do
    let(:test_class) { outer_class.new }

    context 'when replication_ok? is false' do
      before do
        allow(test_class).to receive(:replication_ok?).and_return(false)
      end

      it 'returns false' do
        expect(test_class.replication_and_zip_parts_ok?).to be false
      end
    end

    context 'when zip_parts_ok? is false' do
      before do
        allow(test_class).to receive(:zip_parts_ok?).and_return(false)
      end

      it 'returns false' do
        expect(test_class.replication_and_zip_parts_ok?).to be false
      end
    end

    context 'when replication_ok? and zip_parts_ok? are both true' do
      before do
        allow(test_class).to receive(:replication_ok?).and_return(true)
        allow(test_class).to receive(:zip_parts_ok?).and_return(true)
      end

      it 'returns true' do
        expect(test_class.replication_and_zip_parts_ok?).to be true
      end
    end
  end

  describe '#replication_ok?' do
    let(:endpoint1) { ZipEndpoint.first }
    let(:endpoint2) { ZipEndpoint.last }
    let(:po1) { create(:preserved_object, current_version: 2) }
    let(:po2) { create(:preserved_object, current_version: 1) }

    before do
      # test seeds have 2 ZipEndpoints
      create(:zipped_moab_version, preserved_object: po1, zip_endpoint: endpoint1)
      create(:zipped_moab_version, preserved_object: po1, zip_endpoint: endpoint2)
      create(:zipped_moab_version, preserved_object: po2, zip_endpoint: endpoint1)
      create(:zipped_moab_version, preserved_object: po2, zip_endpoint: endpoint2)
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
      create(:zip_part, size: Numeric::TERABYTE * 1)
      create(:zip_part, size: (Numeric::TERABYTE * 2))
      create(:zip_part, size: (Numeric::TERABYTE * 3))
    end

    it 'returns a hash of suffies as keys and values as counts' do
      expect(outer_class.new.zip_part_suffixes).to eq('.zip' => 3)
    end
  end

  describe '#zip_parts_total_size' do
    before do
      create(:zip_part, size: Numeric::TERABYTE * 1)
      create(:zip_part, size: ((Numeric::TERABYTE * 2) + (Numeric::GIGABYTE * 500)))
      create(:zip_part, size: (Numeric::TERABYTE * 3))
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

  describe '#zip_parts_ok?' do
    before do
      create(:zip_part, status: 'ok')
    end

    context 'when no zip_parts with status other than ok' do
      it 'returns true' do
        expect(outer_class.new.zip_parts_ok?).to be true
      end
    end

    context 'when zip_part has status other than ok' do
      before do
        create(:zip_part, status: 'not_found')
      end

      it 'returns false' do
        expect(outer_class.new.zip_parts_ok?).to be false
      end
    end
  end

  describe '#zip_parts_unreplicated?' do
    context 'when no ZipPart with status unreplicated' do
      it 'returns false' do
        expect(outer_class.new.zip_parts_unreplicated?).to be false
      end
    end

    context 'when at least one ZipPart has status unreplicated' do
      before do
        create(:zip_part, status: :unreplicated)
      end

      it 'returns true' do
        expect(outer_class.new.zip_parts_unreplicated?).to be true
      end
    end
  end

  describe '#zip_parts_not_found?' do
    context 'when no ZipPart with status not_found' do
      it 'returns false' do
        expect(outer_class.new.zip_parts_not_found?).to be false
      end
    end

    context 'when at least one ZipPart has status not_found' do
      before do
        create(:zip_part, status: :not_found)
      end

      it 'returns true' do
        expect(outer_class.new.zip_parts_not_found?).to be true
      end
    end
  end

  describe '#zip_parts_replicated_checksum_mismatch?' do
    context 'when no ZipPart with status replicated_checksum_mismatch' do
      it 'returns false' do
        expect(outer_class.new.zip_parts_replicated_checksum_mismatch?).to be false
      end
    end

    context 'when at least one ZipPart has status replicated_checksum_mismatch' do
      before do
        create(:zip_part, status: :replicated_checksum_mismatch)
      end

      it 'returns true' do
        expect(outer_class.new.zip_parts_replicated_checksum_mismatch?).to be true
      end
    end
  end
end
