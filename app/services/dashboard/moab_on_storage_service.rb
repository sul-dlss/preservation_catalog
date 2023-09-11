# frozen_string_literal: true

require 'action_view' # for number_to_human_size

# services for dashboard
module Dashboard
  # methods pertaining to PreservedObject and MoabRecord database data for dashboard
  module MoabOnStorageService # rubocop:disable Metrics/ModuleLength
    include ActionView::Helpers::NumberHelper # for number_to_human_size
    include InstrumentationSupport

    def moabs_on_storage_ok?
      moab_on_storage_counts_ok? && !any_moab_record_errors?
    end

    def moab_on_storage_counts_ok?
      preserved_object_moab_record_counts_match? &&
        num_object_versions_preserved_object_moab_record_match?
    end

    def storage_root_info # rubocop:disable Metrics/AbcSize
      @storage_root_info ||= begin
        moab_counts = MoabRecord.group(:moab_storage_root_id).annotate(caller).count
        storage_root_info = {}
        MoabStorageRoot.find_each do |storage_root|
          status_counts = MoabRecord.where(moab_storage_root: storage_root).group(:status).annotate(caller).count
          storage_root_info[storage_root.name] =
            {
              storage_location: storage_root.storage_location,
              total_size: number_to_human_size(storage_root.moab_records.annotate(caller).sum(:size)),
              average_size: number_to_human_size(storage_root.moab_records.annotate(caller).average(:size) || 0),
              moab_count: moab_counts.fetch(storage_root.id, 0),
              ok_count: status_counts.fetch('ok', 0),
              invalid_moab_count: status_counts.fetch('invalid_moab', 0),
              invalid_checksum_count: status_counts.fetch('invalid_checksum', 0),
              moab_not_found_count: status_counts.fetch('moab_on_storage_not_found', 0),
              unexpected_version_count: status_counts.fetch('unexpected_version_on_storage', 0),
              validity_unknown_count: status_counts.fetch('validity_unknown', 0),
              fixity_check_expired_count: storage_root.moab_records.fixity_check_expired.annotate(caller).count
            }
        end
        storage_root_info
      end
    end

    def storage_roots_moab_count
      storage_root_totals[:moab_count]
    end

    def storage_roots_moab_count_ok?
      storage_root_totals[:moab_count] == num_moab_records &&
        storage_root_totals[:moab_count] == num_preserved_objects
    end

    def storage_roots_ok_count
      storage_root_totals[:ok_count]
    end

    def storage_roots_ok_count_ok?
      storage_roots_ok_count == MoabRecord.ok.annotate(caller).count
    end

    def storage_roots_invalid_moab_count
      storage_root_totals[:invalid_moab_count]
    end

    def storage_roots_invalid_moab_count_ok?
      storage_roots_invalid_moab_count&.zero? && MoabRecord.invalid_moab.annotate(caller).count.zero?
    end

    def storage_roots_invalid_checksum_count
      storage_root_totals[:invalid_checksum_count]
    end

    def storage_roots_invalid_checksum_count_ok?
      storage_roots_invalid_checksum_count&.zero? && MoabRecord.invalid_checksum.annotate(caller).count.zero?
    end

    def storage_roots_moab_not_found_count
      storage_root_totals[:moab_not_found_count]
    end

    def storage_roots_moab_not_found_count_ok?
      storage_roots_moab_not_found_count&.zero? && MoabRecord.moab_on_storage_not_found.annotate(caller).count.zero?
    end

    def storage_roots_unexpected_version_count
      storage_root_totals[:unexpected_version_count]
    end

    def storage_roots_unexpected_version_count_ok?
      storage_roots_unexpected_version_count&.zero? && MoabRecord.unexpected_version_on_storage.annotate(caller).count.zero?
    end

    def storage_roots_validity_unknown_count
      storage_root_totals[:validity_unknown_count]
    end

    def storage_roots_validity_unknown_count_ok?
      storage_roots_validity_unknown_count&.zero? && MoabRecord.validity_unknown.annotate(caller).count.zero?
    end

    def storage_roots_fixity_check_expired_count
      storage_root_totals[:fixity_check_expired_count]
    end

    def storage_roots_fixity_check_expired_count_ok?
      storage_roots_fixity_check_expired_count == num_moab_expired_checksum_validation
    end

    def moab_record_total_size
      number_to_human_size(MoabRecord.annotate(caller).sum(:size))
    end

    def moab_record_average_size
      number_to_human_size(MoabRecord.annotate(caller).average(:size)) unless num_moab_records.zero?
    end

    def moab_record_status_counts
      # called multiple times, so memoize to avoid db queries
      @moab_record_status_counts ||= MoabRecord.statuses.keys.map { |status| MoabRecord.where(status: status).annotate(caller).count }
    end

    def status_labels
      # called multiple times, so memoize to avoid db queries
      @status_labels ||= MoabRecord.statuses.keys.map { |status| status.tr('_', ' ') }
    end

    def num_moab_expired_checksum_validation
      # used multiple times, so memoize to avoid db queries
      @num_moab_expired_checksum_validation ||= MoabRecord.fixity_check_expired.annotate(caller).count
    end

    def moabs_with_expired_checksum_validation?
      num_moab_expired_checksum_validation.positive?
    end

    def any_moab_record_errors?
      num_moab_record_not_ok.positive?
    end

    def num_moab_record_not_ok
      # used multiple times, so memoize to avoid db queries
      @num_moab_record_not_ok ||= MoabRecord.count - MoabRecord.ok.count
    end

    def num_preserved_objects
      # used multiple times, so memoize to avoid db queries
      @num_preserved_objects ||= PreservedObject.annotate(caller).count
    end

    def preserved_object_highest_version
      preserved_object_ordered_version_counts.keys.last
    end

    # total number of object versions according to PreservedObject table
    def num_object_versions_per_preserved_object
      # used multiple times, so memoize to avoid db queries
      @num_object_versions_per_preserved_object ||= PreservedObject.annotate(caller).sum(:current_version)
    end

    def average_version_per_preserved_object
      PreservedObject.annotate(caller).pick(Arel.sql('SUM(current_version)::numeric/COUNT(id)')).round(2) unless num_preserved_objects.zero?
    end

    def num_moab_records
      # used multiple times; memoizing to avoid multiple db queries
      @num_moab_records ||= MoabRecord.annotate(caller).count
    end

    def moab_record_highest_version
      moab_record_ordered_version_counts.keys.last
    end

    # total number of object versions according to MoabRecord table
    def num_object_versions_per_moab_record
      # used multiple times, so memoize to avoid multiple db queries
      @num_object_versions_per_moab_record ||= MoabRecord.annotate(caller).sum(:version)
    end

    def average_version_per_moab_record
      # note, no user input to sanitize here, so ok to use Arel.sql
      # see https://api.rubyonrails.org/v7.0.4/classes/ActiveRecord/UnknownAttributeReference.html
      MoabRecord.annotate(caller).pick(Arel.sql('SUM(version)::numeric/COUNT(id)')).round(2) unless num_moab_records.zero?
    end

    def preserved_object_moab_record_counts_match?
      num_preserved_objects == num_moab_records
    end

    def num_object_versions_preserved_object_moab_record_match?
      num_object_versions_per_preserved_object == num_object_versions_per_moab_record
    end

    def highest_version_preserved_object_moab_record_match?
      preserved_object_highest_version == moab_record_highest_version
    end

    private

    def preserved_object_ordered_version_counts
      # called multiple times, so memoize to avoid db queries
      @preserved_object_ordered_version_counts ||= PreservedObject.group(:current_version).annotate(caller).count.sort.to_h
    end

    def moab_record_ordered_version_counts
      # called multiple times, so memoize to avoid db queries
      @moab_record_ordered_version_counts ||= MoabRecord.group(:version).annotate(caller).count.sort.to_h
    end

    # create this hash so we don't need to loop through storage_root_info multiple times
    def storage_root_totals # rubocop:disable Metrics/AbcSize
      @storage_root_totals ||=
        if storage_root_info.values.empty?
          {}
        else
          moab_count = 0
          ok_count = 0
          invalid_moab_count = 0
          invalid_checksum_count = 0
          moab_not_found_count = 0
          unexpected_version_count = 0
          validity_unknown_count = 0
          fixity_check_expired_count = 0

          storage_root_info.each_key do |root_name|
            moab_count += storage_root_info[root_name][:moab_count]
            ok_count += storage_root_info[root_name][:ok_count]
            invalid_moab_count += storage_root_info[root_name][:invalid_moab_count]
            invalid_checksum_count += storage_root_info[root_name][:invalid_checksum_count]
            moab_not_found_count += storage_root_info[root_name][:moab_not_found_count]
            unexpected_version_count += storage_root_info[root_name][:unexpected_version_count]
            validity_unknown_count += storage_root_info[root_name][:validity_unknown_count]
            fixity_check_expired_count += storage_root_info[root_name][:fixity_check_expired_count]
          end

          {
            moab_count: moab_count,
            ok_count: ok_count,
            invalid_moab_count: invalid_moab_count,
            invalid_checksum_count: invalid_checksum_count,
            moab_not_found_count: moab_not_found_count,
            unexpected_version_count: unexpected_version_count,
            validity_unknown_count: validity_unknown_count,
            fixity_check_expired_count: fixity_check_expired_count
          }
        end
    end
  end
end
