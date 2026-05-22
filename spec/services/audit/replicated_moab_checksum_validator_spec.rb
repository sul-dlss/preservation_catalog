# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Audit::ReplicatedMoabChecksumValidator do
  # single-part: 1 ZMV with 1 ZipPart → part count equals ZMV count
  let!(:single_part_po) { create(:preserved_object, druid: 'bc123df4567') }
  let!(:single_part_zmv) { create(:zipped_moab_version, preserved_object: single_part_po) }
  let!(:single_part_zip_part) { create(:zip_part, zipped_moab_version: single_part_zmv, suffix: '.zip') }

  # multi-part: 1 ZMV with 2 ZipParts → part count exceeds ZMV count
  let!(:multi_part_po) { create(:preserved_object, druid: 'gh456jk8901') }
  let!(:multi_part_zmv) { create(:zipped_moab_version, preserved_object: multi_part_po) }
  let!(:multi_part_zip_part1) { create(:zip_part, zipped_moab_version: multi_part_zmv, suffix: '.zip') }
  let!(:multi_part_zip_part2) { create(:zip_part, zipped_moab_version: multi_part_zmv, suffix: '.z01') }

  describe '.druids_having_single_part_versions' do
    it 'returns druids whose every ZMV has exactly one zip part, not druids with any multi-part ZMV' do
      result = described_class.druids_having_single_part_versions(10)
      expect(result).to include(single_part_po.druid)
      expect(result).not_to include(multi_part_po.druid)
    end
  end

  describe '.druids_having_a_multi_part_version' do
    it 'returns druids with at least one multi-part ZMV, not druids where all ZMVs are single-part' do
      result = described_class.druids_having_a_multi_part_version(10)
      expect(result).to include(multi_part_po.druid)
      expect(result).not_to include(single_part_po.druid)
    end
  end
end
