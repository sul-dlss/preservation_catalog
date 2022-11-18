# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DashboardCatalogHelper do
  let(:storage_root) { create(:moab_storage_root) }

  describe '#catalog_ok?' do
    context 'when PreservedObject and CompleteMoab counts are different' do
      before do
        po1 = create(:preserved_object)
        create(:preserved_object)
        create(:complete_moab, preserved_object: po1, moab_storage_root: storage_root)
      end

      it 'returns false' do
        expect(helper.catalog_ok?).to be false
      end
    end

    context 'when version counts for PreservedObject and CompleteMoab are different' do
      before do
        po1 = create(:preserved_object, current_version: 2)
        po2 = create(:preserved_object, current_version: 2)
        create(:complete_moab, preserved_object: po1, version: 3)
        create(:complete_moab, preserved_object: po2, version: 2)
      end

      it 'returns false' do
        expect(helper.catalog_ok?).to be false
      end
    end

    context 'when PreservedObject and CompleteMoab counts match and version counts match' do
      before do
        po1 = create(:preserved_object, current_version: 3)
        po2 = create(:preserved_object, current_version: 2)
        create(:complete_moab, preserved_object: po1, version: 3)
        create(:complete_moab, preserved_object: po2, version: 2)
      end

      it 'returns true' do
        expect(helper.catalog_ok?).to be true
      end
    end
  end

  describe '#any_complete_moab_errors?' do
    before do
      create(:complete_moab, status: 'ok')
      create(:complete_moab, status: 'ok')
    end

    context 'when there are no errors' do
      it 'returns false' do
        expect(helper.any_complete_moab_errors?).to be false
      end
    end

    context 'when there are errors' do
      before do
        create(:complete_moab, status: 'invalid_moab')
      end

      it 'returns true' do
        expect(helper.any_complete_moab_errors?).to be true
      end
    end
  end

  describe '#num_complete_moab_not_ok' do
    before do
      create(:complete_moab, status: 'ok')
      create(:complete_moab, status: 'ok')
    end

    context 'when all CompleteMoabs are status ok' do
      it 'is 0' do
        expect(helper.num_complete_moab_not_ok).to eq 0
      end
    end

    context 'when a CompleteMoab has status other than ok' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'invalid_moab')
        create(:complete_moab, status: 'invalid_checksum')
        create(:complete_moab, status: 'online_moab_not_found')
        create(:complete_moab, status: 'unexpected_version_on_storage')
        create(:complete_moab, status: 'validity_unknown')
      end

      it 'is not 0' do
        expect(helper.num_complete_moab_not_ok).to eq 5
      end
    end
  end

  describe '#num_preserved_objects' do
    before do
      create_list(:preserved_object, 2)
    end

    it 'returns PreservedObject.count' do
      expect(helper.num_preserved_objects).to eq(PreservedObject.count)
      expect(helper.num_preserved_objects).to eq 2
    end
  end

  describe '#num_object_versions_per_preserved_object' do
    before do
      create(:preserved_object, current_version: 1)
      create(:preserved_object, current_version: 67)
      create(:preserved_object, current_version: 3)
    end

    it 'returns the total number of object versions according to PreservedObject table' do
      expect(helper.num_object_versions_per_preserved_object).to eq 71
    end
  end

  describe '#num_complete_moabs' do
    before do
      storage_root.complete_moabs = build_list(:complete_moab, 2)
    end

    it 'returns CompleteMoab.count' do
      expect(helper.num_complete_moabs).to eq(CompleteMoab.count)
      expect(helper.num_complete_moabs).to eq 2
    end
  end

  describe '#num_object_versions_per_complete_moab' do
    before do
      create(:complete_moab, version: 1)
      create(:complete_moab, version: 67)
      create(:complete_moab, version: 3)
    end

    it 'returns the total number of object versions according to CompleteMoab table' do
      expect(helper.num_object_versions_per_complete_moab).to eq 71
    end
  end
end
