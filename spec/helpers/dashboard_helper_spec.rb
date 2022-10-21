# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DashboardHelper do
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

  describe '#validate_moab_audit_ok?' do
    context 'when there are CompleteMoabs with invalid_moab status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'invalid_moab')
        create(:complete_moab, status: 'ok')
      end

      it 'returns false' do
        expect(helper.validate_moab_audit_ok?).to be false
      end
    end

    context 'when there are CompleteMoabs with online_moab_not_found status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'online_moab_not_found')
      end

      it 'returns false' do
        expect(helper.validate_moab_audit_ok?).to be false
      end
    end

    context 'when there are no CompleteMoabs with either online_moab_not_found or invalid_moab status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'invalid_checksum')
      end

      it 'returns true' do
        expect(helper.validate_moab_audit_ok?).to be true
      end
    end
  end

  describe '#catalog_to_moab_audit_ok?' do
    context 'when there are CompleteMoabs with unexpected_version_on_storage status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'unexpected_version_on_storage')
        create(:complete_moab, status: 'ok')
      end

      it 'returns false' do
        expect(helper.catalog_to_moab_audit_ok?).to be false
      end
    end

    context 'when there are CompleteMoabs with online_moab_not_found status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'online_moab_not_found')
      end

      it 'returns false' do
        expect(helper.catalog_to_moab_audit_ok?).to be false
      end
    end

    context 'when there are no CompleteMoabs with either online_moab_not_found or unexpected_version_on_storage status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'invalid_checksum')
      end

      it 'returns true' do
        expect(helper.catalog_to_moab_audit_ok?).to be true
      end
    end
  end

  describe '#moab_to_catalog_audit_ok?' do
    before do
      create(:complete_moab, status: 'ok')
      create(:complete_moab, status: 'ok')
    end

    context 'when status other than ok for at least one CompleteMoab' do
      before do
        create(:complete_moab, status: 'unexpected_version_on_storage')
      end

      it 'returns false' do
        expect(helper.moab_to_catalog_audit_ok?).to be false
      end
    end

    context 'when all CompleteMoabs have status ok' do
      it 'returns true' do
        expect(helper.moab_to_catalog_audit_ok?).to be true
      end
    end
  end

  describe '#checksum_validation_audit_ok?' do
    context 'when there are CompleteMoabs with online_moab_not_found status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'invalid_checksum')
      end

      it 'returns false' do
        expect(helper.checksum_validation_audit_ok?).to be false
      end
    end

    context 'when there are no CompleteMoabs with either online_moab_not_found or unexpected_version_on_storage status' do
      before do
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'ok')
        create(:complete_moab, status: 'unexpected_version_on_storage')
      end

      it 'returns true' do
        expect(helper.checksum_validation_audit_ok?).to be true
      end
    end
  end

  describe '#catalog_to_archive_audit_ok?' do
    before do
      create(:zip_part, status: 'ok')
      create(:zip_part, status: 'ok')
    end

    context 'when all ZipParts have ok status' do
      it 'is true' do
        expect(helper.catalog_to_archive_audit_ok?).to be true
      end
    end

    context 'when all ZipParts do not have ok status' do
      before do
        create(:zip_part, status: 'replicated_checksum_mismatch')
      end

      it 'is false' do
        expect(helper.catalog_to_archive_audit_ok?).to be false
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
    #       CompleteMoab::STATUSES.map { |status| storage_root.complete_moabs.where(status: status).count },
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
      expect(helper.storage_root_total_count).to eq 3
    end
  end

  describe '#storage_root_total_ok_count' do
    before do
      create(:complete_moab, moab_storage_root: storage_root)
      create(:complete_moab, moab_storage_root: storage_root, status: 'invalid_checksum')
      create(:complete_moab, moab_storage_root: create(:moab_storage_root))
    end

    it 'returns total number of Moabs with status ok on all storage roots' do
      expect(helper.storage_root_total_ok_count).to eq 2
    end
  end

  describe '#complete_moab_total_size' do
    before do
      create(:complete_moab, size: 1 * Numeric::TERABYTE)
      create(:complete_moab, size: (2 * Numeric::TERABYTE) + (500 * Numeric::GIGABYTE))
      create(:complete_moab, size: (3 * Numeric::TERABYTE))
    end

    it 'returns the total size of CompleteMoabs in Terabytes as a string' do
      expect(helper.complete_moab_total_size).to eq '6.49 Tb'
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
        expect(helper.complete_moab_average_size).to eq '1.33 Mb'
      end
    end

    context 'when num_complete_moabs is 0' do
      # this avoids a divide by zero error when running locally
      before do
        allow(helper).to receive(:num_complete_moabs).and_return(0)
      end

      it 'returns nil' do
        expect(helper.complete_moab_average_size).to be_nil
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
      expect(helper.complete_moab_status_counts).to eq [2, 1, 3, 1, 1, 2]
    end
  end

  describe '#status_labels' do
    it 'returns CompleteMoab::STATUSES with blanks instead of underscores' do
      expect(helper.status_labels).to eq ['ok',
                                          'invalid moab',
                                          'invalid checksum',
                                          'online moab not found',
                                          'unexpected version on storage',
                                          'validity unknown']
    end
  end

  describe '#moab_audit_age_threshold' do
    it 'returns string version of MOAB_LAST_VERSION_AUDIT_THRESHOLD ago' do
      expect(helper.moab_audit_age_threshold).to be_a(String)
      result = DateTime.parse(helper.moab_audit_age_threshold)
      expect(result).to be <= DateTime.now - DashboardHelper::MOAB_LAST_VERSION_AUDIT_THRESHOLD
    end
  end

  context 'when at least one CompleteMoab has last_version_audit older than MOAB_LAST_VERSION_AUDIT_THRESHOLD' do
    before do
      create(:complete_moab, last_version_audit: 45.days.ago)
      create(:complete_moab, last_version_audit: 1.day.ago)
      create(:complete_moab, last_version_audit: 2.days.ago)
      create(:complete_moab, last_version_audit: 30.days.ago)
    end

    describe '#num_moab_audits_older_than_threshold' do
      it 'returns a number greater than 0' do
        expect(helper.num_moab_audits_older_than_threshold).to be > 0
        expect(helper.num_moab_audits_older_than_threshold).to eq 2
      end
    end

    describe '#moab_audits_older_than_threshold?' do
      it 'is true' do
        expect(helper.moab_audits_older_than_threshold?).to be true
      end
    end
  end

  context 'when no CompleteMoabs have last_version_audit older than MOAB_LAST_VERSION_AUDIT_THRESHOLD' do
    before do
      create(:complete_moab, last_version_audit: 5.days.ago)
    end

    describe '#num_moab_audits_older_than_threshold' do
      it 'returns 0' do
        expect(helper.num_moab_audits_older_than_threshold).to eq 0
      end
    end

    describe '#moab_audits_older_than_threshold?' do
      it 'is false' do
        expect(helper.moab_audits_older_than_threshold?).to be false
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
      expect(helper.num_expired_checksum_validation).to eq(2)
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

  describe '#replication_audit_age_threshold' do
    it 'returns string version of REPLICATION_AUDIT_THRESHOLD ago' do
      expect(helper.replication_audit_age_threshold).to be_a(String)
      result = DateTime.parse(helper.replication_audit_age_threshold)
      expect(result).to be <= DateTime.now - DashboardHelper::REPLICATION_AUDIT_THRESHOLD
    end
  end

  context 'when at least one PreservedObject has archive_check_expired' do
    before do
      create(:preserved_object, last_archive_audit: 95.days.ago)
      create(:preserved_object) # last_archive_audit is nil so it counts
      create(:preserved_object, last_archive_audit: 132.days.ago)
      create(:preserved_object, last_archive_audit: 5.days.ago)
    end

    describe '#num_replication_audits_older_than_threshold' do
      it 'returns a number greater than 0' do
        expect(helper.num_replication_audits_older_than_threshold).to be > 0
        expect(helper.num_replication_audits_older_than_threshold).to eq 3
      end
    end

    describe '#replication_audits_older_than_threshold?' do
      it 'is true' do
        expect(helper.replication_audits_older_than_threshold?).to be true
      end
    end
  end

  context 'when no PreservedObjects have last_version_audit older than archive_check_expired' do
    before do
      create(:preserved_object, last_archive_audit: 5.days.ago)
      create(:preserved_object, last_archive_audit: 2.days.ago)
    end

    describe '#num_replication_audits_older_than_threshold' do
      it 'returns 0' do
        expect(helper.num_replication_audits_older_than_threshold).to eq 0
      end
    end

    describe '#replication_audits_older_than_threshold?' do
      it 'is false' do
        expect(helper.replication_audits_older_than_threshold?).to be false
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

  describe '#preserved_object_highest_version' do
    before do
      create(:preserved_object, current_version: 1)
      create(:preserved_object, current_version: 67)
      create(:preserved_object, current_version: 3)
    end

    it 'returns the highest current_version value of any PreservedObject' do
      expect(helper.preserved_object_highest_version).to eq 67
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

  describe '#average_version_per_preserved_object' do
    context 'when there are PreservedObjects' do
      before do
        create(:preserved_object, current_version: 1)
        create(:preserved_object, current_version: 67)
        create(:preserved_object, current_version: 3)
      end

      it 'returns the average number of versions per object according to the PreservedObject table' do
        expect(helper.average_version_per_preserved_object).to eq 23.67
      end
    end

    context 'when there are no PreservedObjects' do
      # this avoids a divide by zero error when running locally
      it 'returns nil' do
        expect(helper.average_version_per_preserved_object).to be_nil
      end
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

  describe '#complete_moab_highest_version' do
    before do
      create(:complete_moab, version: 1)
      create(:complete_moab, version: 67)
      create(:complete_moab, version: 3)
    end

    it 'returns the highest version value of any CompleteMoab' do
      expect(helper.complete_moab_highest_version).to eq 67
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

  describe '#average_version_per_complete_moab' do
    context 'when there are CompleteMoabs' do
      before do
        create(:complete_moab, version: 1)
        create(:complete_moab, version: 67)
        create(:complete_moab, version: 3)
      end

      it 'returns the average number of versions per object accrding to the CompleteMoab table' do
        expect(helper.average_version_per_complete_moab).to eq 23.67
      end
    end

    context 'when there are no CompleteMoabs' do
      # this avoids a divide by zero error when running locally
      it 'returns nil' do
        expect(helper.average_version_per_complete_moab).to be_nil
      end
    end
  end
end
