# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::MoabOnStorageService do
  let(:storage_root) { create(:moab_storage_root) }
  let(:outer_class) do
    Class.new do
      include Dashboard::MoabOnStorageService
    end
  end

  describe '#moabs_on_storage_ok?' do
    context 'when moab_on_storage_counts_ok? is false' do
      before do
        create(:preserved_object) # create a preserved object without a complete moab
      end

      it 'returns false' do
        expect(outer_class.new.moabs_on_storage_ok?).to be false
      end
    end

    context 'when any_complete_moab_errors? is true' do
      before do
        create(:complete_moab, status: :invalid_moab, moab_storage_root: storage_root)
      end

      it 'returns false' do
        expect(outer_class.new.moabs_on_storage_ok?).to be false
      end
    end

    context 'when moab_on_storage_counts_ok? is true and any_complete_moab_errors? is false' do
      before do
        create(:complete_moab, status: :ok, moab_storage_root: storage_root)
      end

      it 'returns true' do
        expect(outer_class.new.moabs_on_storage_ok?).to be true
      end
    end
  end

  describe '#moab_on_storage_counts_ok?' do
    context 'when PreservedObject and CompleteMoab counts are different' do
      before do
        po1 = create(:preserved_object)
        create(:preserved_object)
        create(:complete_moab, preserved_object: po1, moab_storage_root: storage_root)
      end

      it 'returns false' do
        expect(outer_class.new.moab_on_storage_counts_ok?).to be false
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
        expect(outer_class.new.moab_on_storage_counts_ok?).to be false
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
        expect(outer_class.new.moab_on_storage_counts_ok?).to be true
      end
    end
  end

  describe '#storage_root_info' do
    skip('FIXME: intend to change this internal structure soon; not testing yet')
    # storage_root_info = {}
    # MoabStorageRoot.all.each do |storage_root|
    #   storage_root_info[storage_root.name] =
    #     [
    #       storage_root.storage_location,
    #       "#{(storage_root.complete_moabs.sum(:size) / Numeric::TERABYTE).to_f.round(2)} Tb",
    #       "#{((storage_root.complete_moabs.average(:size) || 0) / Numeric::MEGABYTE).to_f.round(2)} Mb",
    #       storage_root.complete_moabs.count,
    #       CompleteMoab.statuses.keys.map { |status| storage_root.complete_moabs.where(status: status).count },
    #       storage_root.complete_moabs.fixity_check_expired.count
    #     ].flatten
    # end
    # storage_root_info
  end

  # @return [Array<Integer>] totals of counts from each storage root for:
  #   total of counts of each CompleteMoab status (ok, invalid_checksum, etc.)
  #   total of counts of fixity_check_expired
  #   total of complete_moab counts - this is last element in array due to index shift to skip storage_location and stored size
  describe '#storage_root_totals' do
    skip('FIXME: intend to change storage_root_info internal structure soon; not testing yet')
    # return [0] if storage_root_info.values.size.zero?

    # totals = Array.new(storage_root_info.values.first.size - 3, 0)
    # storage_root_info.each_key do |root_name|
    #   storage_root_info[root_name][3..].each_with_index do |count, index|
    #     totals[index] += count
    #   end
    # end
    # totals
  end

  describe '#storage_root_total_count' do
    before do
      create(:complete_moab, moab_storage_root: storage_root)
      create(:complete_moab, moab_storage_root: storage_root, status: 'invalid_checksum')
      create(:complete_moab, moab_storage_root: create(:moab_storage_root))
    end

    it 'returns total number of Moabs on all storage roots' do
      expect(outer_class.new.storage_root_total_count).to eq 3
    end
  end

  describe '#storage_root_total_ok_count' do
    before do
      create(:complete_moab, moab_storage_root: storage_root)
      create(:complete_moab, moab_storage_root: storage_root, status: 'invalid_checksum')
      create(:complete_moab, moab_storage_root: create(:moab_storage_root))
    end

    it 'returns total number of Moabs with status ok on all storage roots' do
      expect(outer_class.new.storage_root_total_ok_count).to eq 2
    end
  end

  describe '#complete_moab_total_size' do
    before do
      create(:complete_moab, size: 1 * Numeric::TERABYTE)
      create(:complete_moab, size: (2 * Numeric::TERABYTE) + (500 * Numeric::GIGABYTE))
      create(:complete_moab, size: (3 * Numeric::TERABYTE))
    end

    it 'returns the total size of CompleteMoabs in Terabytes as a string' do
      expect(outer_class.new.complete_moab_total_size).to eq '6.49 TB'
    end
  end

  describe '#complete_moab_average_size' do
    context 'when there are CompleteMoabs' do
      before do
        create(:complete_moab, size: 1 * Numeric::MEGABYTE)
        create(:complete_moab, size: (2 * Numeric::KILOBYTE))
        create(:complete_moab, size: (3 * Numeric::MEGABYTE))
      end
      # "#{(CompleteMoab.average(:size) / Numeric::MEGABYTE).to_f.round(2)} Mb" unless num_complete_moabs.zero?

      it 'returns the average size of CompleteMoabs in Megabytes as a string' do
        expect(outer_class.new.complete_moab_average_size).to eq '1.33 MB'
      end
    end

    context 'when num_complete_moabs is 0' do
      # this avoids a divide by zero error when running locally
      before do
        allow(outer_class.new).to receive(:num_complete_moabs).and_return(0)
      end

      it 'returns nil' do
        expect(outer_class.new.complete_moab_average_size).to be_nil
      end
    end
  end

  describe '#complete_moab_status_counts' do
    before do
      create(:complete_moab, status: 'ok')
      create(:complete_moab, status: 'ok')
      create(:complete_moab, status: 'invalid_moab')
      create(:complete_moab, status: 'invalid_checksum')
      create(:complete_moab, status: 'invalid_checksum')
      create(:complete_moab, status: 'online_moab_not_found')
      create(:complete_moab, status: 'invalid_checksum')
      create(:complete_moab, status: 'unexpected_version_on_storage')
      create(:complete_moab, status: 'validity_unknown')
      create(:complete_moab, status: 'validity_unknown')
    end

    it 'returns array of counts for each CompleteMoab status' do
      expect(outer_class.new.complete_moab_status_counts).to eq [2, 1, 3, 1, 1, 2]
    end
  end

  describe '#status_labels' do
    it 'returns CompleteMoab.statuses.keys with blanks instead of underscores' do
      expect(outer_class.new.status_labels).to eq ['ok',
                                                   'invalid moab',
                                                   'invalid checksum',
                                                   'online moab not found',
                                                   'unexpected version on storage',
                                                   'validity unknown']
    end
  end

  describe '#any_complete_moab_errors?' do
    before do
      create(:complete_moab, status: 'ok')
      create(:complete_moab, status: 'ok')
    end

    context 'when there are no errors' do
      it 'returns false' do
        expect(outer_class.new.any_complete_moab_errors?).to be false
      end
    end

    context 'when there are errors' do
      before do
        create(:complete_moab, status: 'invalid_moab')
      end

      it 'returns true' do
        expect(outer_class.new.any_complete_moab_errors?).to be true
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
        expect(outer_class.new.num_complete_moab_not_ok).to eq 0
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
        expect(outer_class.new.num_complete_moab_not_ok).to eq 5
      end
    end
  end

  describe '#num_preserved_objects' do
    before do
      create_list(:preserved_object, 2)
    end

    it 'returns PreservedObject.count' do
      expect(outer_class.new.num_preserved_objects).to eq(PreservedObject.count)
      expect(outer_class.new.num_preserved_objects).to eq 2
    end
  end

  describe '#preserved_object_highest_version' do
    before do
      create(:preserved_object, current_version: 1)
      create(:preserved_object, current_version: 67)
      create(:preserved_object, current_version: 3)
    end

    it 'returns the highest current_version value of any PreservedObject' do
      expect(outer_class.new.preserved_object_highest_version).to eq 67
    end
  end

  describe '#num_object_versions_per_preserved_object' do
    before do
      create(:preserved_object, current_version: 1)
      create(:preserved_object, current_version: 67)
      create(:preserved_object, current_version: 3)
    end

    it 'returns the total number of object versions according to PreservedObject table' do
      expect(outer_class.new.num_object_versions_per_preserved_object).to eq 71
    end
  end

  describe '#average_version_per_preserved_object' do
    context 'when there are PreservedObjects' do
      before do
        create(:preserved_object, current_version: 1)
        create(:preserved_object, current_version: 67)
        create(:preserved_object, current_version: 3)
      end

      it 'returns the average number of versions per object according to the PreservedObject table' do
        expect(outer_class.new.average_version_per_preserved_object).to eq 23.67
      end
    end

    context 'when there are no PreservedObjects' do
      # this avoids a divide by zero error when running locally
      it 'returns nil' do
        expect(outer_class.new.average_version_per_preserved_object).to be_nil
      end
    end
  end

  describe '#num_complete_moabs' do
    before do
      storage_root.complete_moabs = build_list(:complete_moab, 2)
    end

    it 'returns CompleteMoab.count' do
      expect(outer_class.new.num_complete_moabs).to eq(CompleteMoab.count)
      expect(outer_class.new.num_complete_moabs).to eq 2
    end
  end

  describe '#complete_moab_highest_version' do
    before do
      create(:complete_moab, version: 1)
      create(:complete_moab, version: 67)
      create(:complete_moab, version: 3)
    end

    it 'returns the highest version value of any CompleteMoab' do
      expect(outer_class.new.complete_moab_highest_version).to eq 67
    end
  end

  describe '#num_object_versions_per_complete_moab' do
    before do
      create(:complete_moab, version: 1)
      create(:complete_moab, version: 67)
      create(:complete_moab, version: 3)
    end

    it 'returns the total number of object versions according to CompleteMoab table' do
      expect(outer_class.new.num_object_versions_per_complete_moab).to eq 71
    end
  end

  describe '#average_version_per_complete_moab' do
    context 'when there are CompleteMoabs' do
      before do
        create(:complete_moab, version: 1)
        create(:complete_moab, version: 67)
        create(:complete_moab, version: 3)
      end

      it 'returns the average number of versions per object accrding to the CompleteMoab table' do
        expect(outer_class.new.average_version_per_complete_moab).to eq 23.67
      end
    end

    context 'when there are no CompleteMoabs' do
      # this avoids a divide by zero error when running locally
      it 'returns nil' do
        expect(outer_class.new.average_version_per_complete_moab).to be_nil
      end
    end
  end

  describe '#num_expired_checksum_validation' do
    before do
      create(:complete_moab, moab_storage_root: storage_root, last_checksum_validation: Time.zone.now)
      create(:complete_moab, preserved_object: create(:preserved_object), last_checksum_validation: 4.months.ago)
      create(:complete_moab, moab_storage_root: storage_root)
    end

    it 'returns CompleteMoab.fixity_check_expired.count and includes nil in the count' do
      expect(outer_class.new.num_expired_checksum_validation).to eq(2)
    end
  end

  describe '#moabs_with_expired_checksum_validation?' do
    context 'when there are no expired checksum validations' do
      before do
        create(:complete_moab, moab_storage_root: storage_root, last_checksum_validation: Time.zone.now)
      end

      it 'returns false' do
        expect(outer_class.new.moabs_with_expired_checksum_validation?).to be false
      end
    end

    context 'when there are expired checksum validations' do
      before do
        create(:complete_moab, moab_storage_root: storage_root, last_checksum_validation: 4.months.ago)
      end

      it 'returns true' do
        expect(outer_class.new.moabs_with_expired_checksum_validation?).to be true
      end
    end
  end

  describe 'preserved_object_complete_moab_counts_match?' do
    before do
      storage_root.complete_moabs = build_list(:complete_moab, 2)
    end

    context 'when the counts match' do
      it 'returns true' do
        expect(outer_class.new.preserved_object_complete_moab_counts_match?).to be true
      end
    end

    context 'when the counts do not match' do
      before do
        create(:preserved_object, current_version: 1)
      end

      it 'returns false' do
        expect(outer_class.new.preserved_object_complete_moab_counts_match?).to be false
      end
    end
  end

  describe '#num_object_versions_preserved_object_complete_moab_match?' do
    let!(:preserved_object) { create(:preserved_object, current_version: 2) }

    before do
      create(:complete_moab, preserved_object: preserved_object, version: 2)
    end

    context 'when the number of object versions match' do
      it 'returns true' do
        expect(outer_class.new.num_object_versions_preserved_object_complete_moab_match?).to be true
      end
    end

    context 'when the number of object versions do not match' do
      before do
        preserved_object.current_version = 1 # pretend it wasn't updated to version 2
        preserved_object.save!
      end

      it 'returns false' do
        expect(outer_class.new.num_object_versions_preserved_object_complete_moab_match?).to be false
      end
    end
  end

  describe '#highest_version_preserved_object_complete_moab_match?' do
    let!(:preserved_object) { create(:preserved_object, current_version: 2) }

    before do
      create(:complete_moab, preserved_object: preserved_object, version: 2)
    end

    context 'when the highest versions match' do
      it 'returns true' do
        expect(outer_class.new.highest_version_preserved_object_complete_moab_match?).to be true
      end
    end

    context 'when the highest versions do not match' do
      before do
        preserved_object.current_version = 1 # pretend it wasn't updated to version 2
        preserved_object.save!
      end

      it 'returns false' do
        expect(outer_class.new.highest_version_preserved_object_complete_moab_match?).to be false
      end
    end
  end
end
