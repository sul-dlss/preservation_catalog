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
        create(:preserved_object) # create a preserved object without a MoabRecord
      end

      it 'returns false' do
        expect(outer_class.new.moabs_on_storage_ok?).to be false
      end
    end

    context 'when any_moab_record_errors? is true' do
      before do
        create(:moab_record, status: :invalid_moab, moab_storage_root: storage_root)
      end

      it 'returns false' do
        expect(outer_class.new.moabs_on_storage_ok?).to be false
      end
    end

    context 'when moab_on_storage_counts_ok? is true and any_moab_record_errors? is false' do
      before do
        create(:moab_record, status: :ok, moab_storage_root: storage_root)
      end

      it 'returns true' do
        expect(outer_class.new.moabs_on_storage_ok?).to be true
      end
    end
  end

  describe '#moab_on_storage_counts_ok?' do
    context 'when PreservedObject and MoabRecord counts are different' do
      before do
        po1 = create(:preserved_object)
        create(:preserved_object)
        create(:moab_record, preserved_object: po1, moab_storage_root: storage_root)
      end

      it 'returns false' do
        expect(outer_class.new.moab_on_storage_counts_ok?).to be false
      end
    end

    context 'when version counts for PreservedObject and MoabRecord are different' do
      before do
        po1 = create(:preserved_object, current_version: 2)
        po2 = create(:preserved_object, current_version: 2)
        create(:moab_record, preserved_object: po1, version: 3)
        create(:moab_record, preserved_object: po2, version: 2)
      end

      it 'returns false' do
        expect(outer_class.new.moab_on_storage_counts_ok?).to be false
      end
    end

    context 'when PreservedObject and MoabRecord counts match and version counts match' do
      before do
        po1 = create(:preserved_object, current_version: 3)
        po2 = create(:preserved_object, current_version: 2)
        create(:moab_record, preserved_object: po1, version: 3)
        create(:moab_record, preserved_object: po2, version: 2)
      end

      it 'returns true' do
        expect(outer_class.new.moab_on_storage_counts_ok?).to be true
      end
    end
  end

  describe '#storage_root_info' do
    let(:storage_root2) { create(:moab_storage_root) }
    let(:expected_average_size) { '231 Bytes' }
    let(:expected_total_size) { '462 Bytes' }

    before do
      create(:moab_record, moab_storage_root: storage_root)
      create(:moab_record, moab_storage_root: storage_root, status: 'invalid_checksum')
      create(:moab_record, moab_storage_root: storage_root2)
    end

    it 'has the expected data' do
      expect(outer_class.new.storage_root_info).to include(
        storage_root.name => {
          storage_location: storage_root.storage_location,
          total_size: expected_total_size,
          average_size: expected_average_size,
          moab_count: 2,
          ok_count: 1,
          invalid_moab_count: 0,
          invalid_checksum_count: 1,
          moab_not_found_count: 0,
          unexpected_version_count: 0,
          validity_unknown_count: 0,
          fixity_check_expired_count: 2
        },
        storage_root2.name => {
          storage_location: storage_root2.storage_location,
          total_size: expected_average_size,
          average_size: expected_average_size,
          moab_count: 1,
          ok_count: 1,
          invalid_moab_count: 0,
          invalid_checksum_count: 0,
          moab_not_found_count: 0,
          unexpected_version_count: 0,
          validity_unknown_count: 0,
          fixity_check_expired_count: 1
        }
      )
    end
  end

  describe 'storage roots (total) xx_count and xx_count_ok?' do
    let(:storage_root2) { create(:moab_storage_root) }

    before do
      create(:moab_record, moab_storage_root: storage_root, last_checksum_validation: 1.day.ago)
      create(:moab_record, moab_storage_root: storage_root, status: 'invalid_checksum', last_checksum_validation: 1.day.ago)
      create(:moab_record, moab_storage_root: storage_root2, status: 'ok', last_checksum_validation: 1.day.ago)
    end

    describe '#storage_roots_moab_count' do
      it 'is the number of moab_records on each storage root, totalled' do
        expect(outer_class.new.storage_roots_moab_count).to eq 3
      end
    end

    describe '#storage_roots_moab_count_ok?' do
      context 'when storage_roots_moab_count matches MoabRecord.count' do
        it 'true' do
          expect(outer_class.new.storage_roots_moab_count_ok?).to be true
        end
      end

      context 'when storage_roots_moab_count does not match MoabRecord.count' do
        before do
          allow(MoabRecord).to receive(:count).and_return(4)
        end

        it 'false' do
          expect(outer_class.new.storage_roots_moab_count_ok?).to be false
        end
      end

      context 'when storage_roots_moab_count does not match num_preserved_objects' do
        before do
          allow_any_instance_of(outer_class).to receive(:num_preserved_objects).and_return(5) # rubocop:disable RSpec/AnyInstance
        end

        it 'false' do
          expect(outer_class.new.storage_roots_moab_count_ok?).to be false
        end
      end
    end

    describe '#storage_roots_ok_count' do
      it 'is the number of moab_records with ok status on each storage root, totalled' do
        expect(outer_class.new.storage_roots_ok_count).to eq 2
      end
    end

    describe '#storage_roots_ok_count_ok?' do
      context 'when storage_roots_ok_count matches MoabRecord.ok.count' do
        it 'true' do
          expect(outer_class.new.storage_roots_ok_count_ok?).to be true
        end
      end

      context 'when storage_roots_ok_count does not match MoabRecord.ok.count' do
        before do
          allow_any_instance_of(outer_class).to receive(:storage_roots_ok_count).and_return(5) # rubocop:disable RSpec/AnyInstance
        end

        it 'false' do
          expect(outer_class.new.storage_roots_ok_count_ok?).to be false
        end
      end
    end

    describe '#storage_roots_invalid_moab_count' do
      before do
        create(:moab_record, moab_storage_root: storage_root, status: 'invalid_moab')
      end

      it 'is the number of moab_records with invalid_moab status on each storage root, totalled' do
        expect(outer_class.new.storage_roots_invalid_moab_count).to eq 1
      end
    end

    describe '#storage_roots_invalid_moab_count_ok?' do
      context 'when storage_roots_invalid_moab_count is not zero' do
        before do
          create(:moab_record, moab_storage_root: storage_root, status: 'invalid_moab')
        end

        it 'false' do
          expect(outer_class.new.storage_roots_invalid_moab_count_ok?).to be false
        end
      end

      context 'when storage_roots_invalid_moab_count is zero' do
        context 'when MoabRecord.invalid_moab.count is zero' do
          before do
            relation = MoabRecord.where(status: 'invalid_moab')
            allow(relation).to receive(:[]).and_return([MoabRecord.new])
            allow(MoabRecord).to receive(:where).with(status: 'invalid_moab').and_return(relation)
            allow_any_instance_of(outer_class).to receive(:storage_roots_invalid_moab_count).and_return(0) # rubocop:disable RSpec/AnyInstance
          end

          it 'true' do
            expect(outer_class.new.storage_roots_invalid_moab_count_ok?).to be true
          end
        end

        context 'when MoabRecord.invalid_moab.count is not zero' do
          before do
            create(:moab_record, moab_storage_root: storage_root, status: 'invalid_moab')
            allow(outer_class.new).to receive(:storage_roots_invalid_moab_count).and_return(0)
          end

          it 'false' do
            expect(outer_class.new.storage_roots_invalid_moab_count_ok?).to be false
          end
        end
      end
    end

    describe '#storage_roots_invalid_checksum_count' do
      it 'is the number of moab_records with invalid_checksum status on each storage root, totalled' do
        expect(outer_class.new.storage_roots_invalid_checksum_count).to eq 1
      end
    end

    describe '#storage_roots_invalid_checksum_count_ok?' do
      context 'when storage_roots_invalid_checksum_count is not zero' do
        it 'false' do
          expect(outer_class.new.storage_roots_invalid_checksum_count_ok?).to be false
        end
      end

      context 'when storage_roots_invalid_checksum_count is zero' do
        context 'when MoabRecord.invalid_checksum.count is zero' do
          before do
            MoabRecord.invalid_checksum.delete_all
            allow_any_instance_of(outer_class).to receive(:storage_roots_invalid_checksum_count).and_return(0) # rubocop:disable RSpec/AnyInstance
          end

          it 'true' do
            expect(outer_class.new.storage_roots_invalid_checksum_count_ok?).to be true
          end
        end

        context 'when MoabRecord.invalid_checksum.count is not zero' do
          before do
            create(:moab_record, moab_storage_root: storage_root, status: 'invalid_checksum')
            allow_any_instance_of(outer_class).to receive(:storage_roots_invalid_checksum_count).and_return(0) # rubocop:disable RSpec/AnyInstance
          end

          it 'false' do
            expect(outer_class.new.storage_roots_invalid_checksum_count_ok?).to be false
          end
        end
      end
    end

    describe '#storage_roots_moab_not_found_count' do
      before do
        create(:moab_record, moab_storage_root: storage_root, status: 'moab_on_storage_not_found')
      end

      it 'is the number of moab_records with moab_on_storage_not_found status on each storage root, totalled' do
        expect(outer_class.new.storage_roots_moab_not_found_count).to eq 1
      end
    end

    describe '#storage_roots_moab_not_found_count_ok?' do
      context 'when storage_roots_moab_not_found_count is not zero' do
        before do
          create(:moab_record, moab_storage_root: storage_root, status: 'moab_on_storage_not_found')
        end

        it 'false' do
          expect(outer_class.new.storage_roots_moab_not_found_count_ok?).to be false
        end
      end

      context 'when storage_roots_moab_not_found_count is zero' do
        context 'when MoabRecord.moab_on_storage_not_found.count is zero' do
          it 'true' do
            expect(outer_class.new.storage_roots_moab_not_found_count_ok?).to be true
          end
        end

        context 'when MoabRecord.moab_on_storage_not_found.count is not zero' do
          before do
            create(:moab_record, moab_storage_root: storage_root, status: 'moab_on_storage_not_found')
            allow(outer_class.new).to receive(:storage_roots_moab_not_found_count).and_return(0)
          end

          it 'false' do
            expect(outer_class.new.storage_roots_moab_not_found_count_ok?).to be false
          end
        end
      end
    end

    describe '#storage_roots_unexpected_version_count' do
      before do
        create(:moab_record, moab_storage_root: storage_root, status: 'unexpected_version_on_storage')
      end

      it 'is the number of moab_records with unexpected_version_on_storage status on each storage root, totalled' do
        expect(outer_class.new.storage_roots_unexpected_version_count).to eq 1
      end
    end

    describe '#storage_roots_unexpected_version_count_ok?' do
      context 'when storage_roots_unexpected_version_count is not zero' do
        before do
          create(:moab_record, moab_storage_root: storage_root, status: 'unexpected_version_on_storage')
        end

        it 'false' do
          expect(outer_class.new.storage_roots_unexpected_version_count_ok?).to be false
        end
      end

      context 'when storage_roots_unexpected_version_count is zero' do
        context 'when MoabRecord.unexpected_version_on_storage.count is zero' do
          it 'true' do
            expect(outer_class.new.storage_roots_unexpected_version_count_ok?).to be true
          end
        end

        context 'when MoabRecord.unexpected_version_on_storage.count is not zero' do
          before do
            create(:moab_record, moab_storage_root: storage_root, status: 'unexpected_version_on_storage')
            allow(outer_class.new).to receive(:storage_roots_unexpected_version_count).and_return(0)
          end

          it 'false' do
            expect(outer_class.new.storage_roots_unexpected_version_count_ok?).to be false
          end
        end
      end
    end

    describe '#storage_roots_validity_unknown_count' do
      before do
        create(:moab_record, moab_storage_root: storage_root2, status: 'validity_unknown')
      end

      it 'is the number of moab_records with validity_unknown status on each storage root, totalled' do
        expect(outer_class.new.storage_roots_validity_unknown_count).to eq 1
      end
    end

    describe '#storage_roots_validity_unknown_count_ok?' do
      context 'when storage_roots_validity_unknown_count is not zero' do
        before do
          create(:moab_record, moab_storage_root: storage_root, status: 'validity_unknown')
        end

        it 'false' do
          expect(outer_class.new.storage_roots_validity_unknown_count_ok?).to be false
        end
      end

      context 'when storage_roots_validity_unknown_count is zero' do
        context 'when MoabRecord.storage_roots_validity_unknown_count is zero' do
          it 'true' do
            expect(outer_class.new.storage_roots_validity_unknown_count_ok?).to be true
          end
        end

        context 'when MoabRecord.validity_unknown.count is not zero' do
          before do
            create(:moab_record, moab_storage_root: storage_root, status: 'validity_unknown')
            allow(outer_class.new).to receive(:storage_roots_invalid_moab_count).and_return(0)
          end

          it 'false' do
            expect(outer_class.new.storage_roots_validity_unknown_count_ok?).to be false
          end
        end
      end
    end

    describe '#storage_roots_fixity_check_expired_count' do
      before do
        create(:moab_record, moab_storage_root: storage_root2, last_checksum_validation: 4.months.ago)
      end

      it 'is the number of moab_records with fixity_check_expired on each storage root, totalled' do
        expect(outer_class.new.storage_roots_fixity_check_expired_count).to eq 1
      end
    end

    describe '#storage_roots_fixity_check_expired_count_ok?' do
      context 'when storage_roots_fixity_check_expired_count matches MoabRecord.fixity_check_expired.count' do
        it 'true' do
          expect(outer_class.new.storage_roots_fixity_check_expired_count_ok?).to be true
        end
      end

      context 'when storage_roots_fixity_check_expired_count does not match MoabRecord.fixity_check_expired.count' do
        before do
          allow_any_instance_of(outer_class).to receive(:storage_roots_fixity_check_expired_count).and_return(5) # rubocop:disable RSpec/AnyInstance
        end

        it 'false' do
          expect(outer_class.new.storage_roots_fixity_check_expired_count_ok?).to be false
        end
      end
    end
  end

  describe '#moab_record_total_size' do
    before do
      create(:moab_record, size: 1 * Numeric::TERABYTE)
      create(:moab_record, size: (2 * Numeric::TERABYTE) + (500 * Numeric::GIGABYTE))
      create(:moab_record, size: (3 * Numeric::TERABYTE))
    end

    it 'returns the total size of MoabRecords in Terabytes as a string' do
      expect(outer_class.new.moab_record_total_size).to eq '6.49 TB'
    end
  end

  describe '#moab_record_average_size' do
    context 'when there are MoabRecords' do
      before do
        create(:moab_record, size: 1 * Numeric::MEGABYTE)
        create(:moab_record, size: (2 * Numeric::KILOBYTE))
        create(:moab_record, size: (3 * Numeric::MEGABYTE))
      end
      # "#{(MoabRecord.average(:size) / Numeric::MEGABYTE).to_f.round(2)} Mb" unless num_moab_records.zero?

      it 'returns the average size of MoabRecords in Megabytes as a string' do
        expect(outer_class.new.moab_record_average_size).to eq '1.33 MB'
      end
    end

    context 'when num_moab_records is 0' do
      # this avoids a divide by zero error when running locally
      before do
        allow(outer_class.new).to receive(:num_moab_records).and_return(0)
      end

      it 'returns nil' do
        expect(outer_class.new.moab_record_average_size).to be_nil
      end
    end
  end

  describe '#moab_record_status_counts' do
    before do
      create(:moab_record, status: 'ok')
      create(:moab_record, status: 'ok')
      create(:moab_record, status: 'invalid_moab')
      create(:moab_record, status: 'invalid_checksum')
      create(:moab_record, status: 'invalid_checksum')
      create(:moab_record, status: 'moab_on_storage_not_found')
      create(:moab_record, status: 'invalid_checksum')
      create(:moab_record, status: 'unexpected_version_on_storage')
      create(:moab_record, status: 'validity_unknown')
      create(:moab_record, status: 'validity_unknown')
    end

    it 'returns array of counts for each MoabRecord status' do
      expect(outer_class.new.moab_record_status_counts).to eq [2, 1, 3, 1, 1, 2]
    end
  end

  describe '#status_labels' do
    it 'returns MoabRecord.statuses.keys with blanks instead of underscores' do
      expect(outer_class.new.status_labels).to eq ['ok',
                                                   'invalid moab',
                                                   'invalid checksum',
                                                   'moab on storage not found',
                                                   'unexpected version on storage',
                                                   'validity unknown']
    end
  end

  describe '#any_moab_record_errors?' do
    before do
      create(:moab_record, status: 'ok')
      create(:moab_record, status: 'ok')
    end

    context 'when there are no errors' do
      it 'returns false' do
        expect(outer_class.new.any_moab_record_errors?).to be false
      end
    end

    context 'when there are errors' do
      before do
        create(:moab_record, status: 'invalid_moab')
      end

      it 'returns true' do
        expect(outer_class.new.any_moab_record_errors?).to be true
      end
    end
  end

  describe '#num_moab_record_not_ok' do
    before do
      create(:moab_record, status: 'ok')
      create(:moab_record, status: 'ok')
    end

    context 'when all MoabRecords are status ok' do
      it 'is 0' do
        expect(outer_class.new.num_moab_record_not_ok).to eq 0
      end
    end

    context 'when a MoabRecord has status other than ok' do
      before do
        create(:moab_record, status: 'ok')
        create(:moab_record, status: 'ok')
        create(:moab_record, status: 'invalid_moab')
        create(:moab_record, status: 'invalid_checksum')
        create(:moab_record, status: 'moab_on_storage_not_found')
        create(:moab_record, status: 'unexpected_version_on_storage')
        create(:moab_record, status: 'validity_unknown')
      end

      it 'is not 0' do
        expect(outer_class.new.num_moab_record_not_ok).to eq 5
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

  describe '#num_moab_records' do
    before do
      storage_root.moab_records = build_list(:moab_record, 2)
    end

    it 'returns MoabRecord.count' do
      expect(outer_class.new.num_moab_records).to eq(MoabRecord.count)
      expect(outer_class.new.num_moab_records).to eq 2
    end
  end

  describe '#moab_record_highest_version' do
    before do
      create(:moab_record, version: 1)
      create(:moab_record, version: 67)
      create(:moab_record, version: 3)
    end

    it 'returns the highest version value of any MoabRecord' do
      expect(outer_class.new.moab_record_highest_version).to eq 67
    end
  end

  describe '#num_object_versions_per_moab_record' do
    before do
      create(:moab_record, version: 1)
      create(:moab_record, version: 67)
      create(:moab_record, version: 3)
    end

    it 'returns the total number of object versions according to MoabRecord table' do
      expect(outer_class.new.num_object_versions_per_moab_record).to eq 71
    end
  end

  describe '#average_version_per_moab_record' do
    context 'when there are MoabRecords' do
      before do
        create(:moab_record, version: 1)
        create(:moab_record, version: 67)
        create(:moab_record, version: 3)
      end

      it 'returns the average number of versions per object accrding to the MoabRecord table' do
        expect(outer_class.new.average_version_per_moab_record).to eq 23.67
      end
    end

    context 'when there are no MoabRecords' do
      # this avoids a divide by zero error when running locally
      it 'returns nil' do
        expect(outer_class.new.average_version_per_moab_record).to be_nil
      end
    end
  end

  describe '#num_moab_expired_checksum_validation' do
    before do
      create(:moab_record, moab_storage_root: storage_root, last_checksum_validation: Time.zone.now)
      create(:moab_record, preserved_object: create(:preserved_object), last_checksum_validation: 4.months.ago)
      create(:moab_record, moab_storage_root: storage_root)
    end

    it 'returns MoabRecord.fixity_check_expired.count and includes nil in the count' do
      expect(outer_class.new.num_moab_expired_checksum_validation).to eq(2)
    end
  end

  describe '#moabs_with_expired_checksum_validation?' do
    context 'when there are no expired checksum validations' do
      before do
        create(:moab_record, moab_storage_root: storage_root, last_checksum_validation: Time.zone.now)
      end

      it 'returns false' do
        expect(outer_class.new.moabs_with_expired_checksum_validation?).to be false
      end
    end

    context 'when there are expired checksum validations' do
      before do
        create(:moab_record, moab_storage_root: storage_root, last_checksum_validation: 4.months.ago)
      end

      it 'returns true' do
        expect(outer_class.new.moabs_with_expired_checksum_validation?).to be true
      end
    end
  end

  describe 'preserved_object_moab_record_counts_match?' do
    before do
      storage_root.moab_records = build_list(:moab_record, 2)
    end

    context 'when the counts match' do
      it 'returns true' do
        expect(outer_class.new.preserved_object_moab_record_counts_match?).to be true
      end
    end

    context 'when the counts do not match' do
      before do
        create(:preserved_object, current_version: 1)
      end

      it 'returns false' do
        expect(outer_class.new.preserved_object_moab_record_counts_match?).to be false
      end
    end
  end

  describe '#num_object_versions_preserved_object_moab_record_match?' do
    let!(:preserved_object) { create(:preserved_object, current_version: 2) }

    before do
      create(:moab_record, preserved_object: preserved_object, version: 2)
    end

    context 'when the number of object versions match' do
      it 'returns true' do
        expect(outer_class.new.num_object_versions_preserved_object_moab_record_match?).to be true
      end
    end

    context 'when the number of object versions do not match' do
      before do
        preserved_object.current_version = 1 # pretend it wasn't updated to version 2
        preserved_object.save!
      end

      it 'returns false' do
        expect(outer_class.new.num_object_versions_preserved_object_moab_record_match?).to be false
      end
    end
  end

  describe '#highest_version_preserved_object_moab_record_match?' do
    let!(:preserved_object) { create(:preserved_object, current_version: 2) }

    before do
      create(:moab_record, preserved_object: preserved_object, version: 2)
    end

    context 'when the highest versions match' do
      it 'returns true' do
        expect(outer_class.new.highest_version_preserved_object_moab_record_match?).to be true
      end
    end

    context 'when the highest versions do not match' do
      before do
        preserved_object.current_version = 1 # pretend it wasn't updated to version 2
        preserved_object.save!
      end

      it 'returns false' do
        expect(outer_class.new.highest_version_preserved_object_moab_record_match?).to be false
      end
    end
  end
end
