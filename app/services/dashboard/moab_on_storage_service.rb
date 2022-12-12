# frozen_string_literal: true

require 'action_view' # for number_to_human_size

# services for dashboard
module Dashboard
  # methods pertaining to PreservedObject and CompleteMoab database data for dashboard
  module MoabOnStorageService # rubocop:disable Metrics/ModuleLength
    include ActionView::Helpers::NumberHelper # for number_to_human_size

    def moabs_on_storage_ok?
      moab_on_storage_counts_ok? && !any_complete_moab_errors?
    end

    def moab_on_storage_counts_ok?
      preserved_object_complete_moab_counts_match? &&
        num_object_versions_preserved_object_complete_moab_match?
    end

    def storage_root_info # rubocop:disable Metrics/AbcSize
      @storage_root_info ||= begin
        storage_root_info = {}
        MoabStorageRoot.all.each do |storage_root|
          storage_root_info[storage_root.name] =
            {
              storage_location: storage_root.storage_location,
              total_size: number_to_human_size(storage_root.complete_moabs.sum(:size)),
              average_size: number_to_human_size(storage_root.complete_moabs.average(:size) || 0),
              moab_count: storage_root.complete_moabs.count,
              ok_count: storage_root.complete_moabs.where(status: :ok).count,
              invalid_moab_count: storage_root.complete_moabs.where(status: :invalid_moab).count,
              invalid_checksum_count: storage_root.complete_moabs.where(status: :invalid_checksum).count,
              moab_not_found_count: storage_root.complete_moabs.where(status: :online_moab_not_found).count,
              unexpected_version_count: storage_root.complete_moabs.where(status: :unexpected_version_on_storage).count,
              validity_unknown_count: storage_root.complete_moabs.where(status: :validity_unknown).count,
              fixity_check_expired_count: storage_root.complete_moabs.fixity_check_expired.count
            }
        end
        storage_root_info
      end
    end

    def storage_roots_moab_count
      storage_root_totals[:moab_count]
    end

    def storage_roots_moab_count_ok?
      storage_root_totals[:moab_count] == num_complete_moabs &&
        storage_root_totals[:moab_count] == num_preserved_objects
    end

    def storage_roots_ok_count
      storage_root_totals[:ok_count]
    end

    def storage_roots_ok_count_ok?
      storage_roots_ok_count == CompleteMoab.ok.count
    end

    def storage_roots_invalid_moab_count
      storage_root_totals[:invalid_moab_count]
    end

    def storage_roots_invalid_moab_count_ok?
      storage_roots_invalid_moab_count&.zero? && CompleteMoab.invalid_moab.count.zero?
    end

    def storage_roots_invalid_checksum_count
      storage_root_totals[:invalid_checksum_count]
    end

    def storage_roots_invalid_checksum_count_ok?
      storage_roots_invalid_checksum_count&.zero? && CompleteMoab.invalid_checksum.count.zero?
    end

    def storage_roots_moab_not_found_count
      storage_root_totals[:moab_not_found_count]
    end

    def storage_roots_moab_not_found_count_ok?
      storage_roots_moab_not_found_count&.zero? && CompleteMoab.online_moab_not_found.count.zero?
    end

    def storage_roots_unexpected_version_count
      storage_root_totals[:unexpected_version_count]
    end

    def storage_roots_unexpected_version_count_ok?
      storage_roots_unexpected_version_count&.zero? && CompleteMoab.unexpected_version_on_storage.count.zero?
    end

    def storage_roots_validity_unknown_count
      storage_root_totals[:validity_unknown_count]
    end

    def storage_roots_validity_unknown_count_ok?
      storage_roots_validity_unknown_count&.zero? && CompleteMoab.validity_unknown.count.zero?
    end

    def storage_roots_fixity_check_expired_count
      storage_root_totals[:fixity_check_expired_count]
    end

    def storage_roots_fixity_check_expired_count_ok?
      storage_roots_fixity_check_expired_count == num_moab_expired_checksum_validation
    end

    def complete_moab_total_size
      number_to_human_size(CompleteMoab.sum(:size))
    end

    def complete_moab_average_size
      number_to_human_size(CompleteMoab.average(:size)) unless num_complete_moabs.zero?
    end

    def complete_moab_status_counts
      # called multiple times, so memoize to avoid db queries
      @complete_moab_status_counts ||= CompleteMoab.statuses.keys.map { |status| CompleteMoab.where(status: status).count }
    end

    def status_labels
      # called multiple times, so memoize to avoid db queries
      @status_labels ||= CompleteMoab.statuses.keys.map { |status| status.tr('_', ' ') }
    end

    def num_moab_expired_checksum_validation
      # used multiple times, so memoize to avoid db queries
      @num_moab_expired_checksum_validation ||= CompleteMoab.fixity_check_expired.count
    end

    def moabs_with_expired_checksum_validation?
      num_moab_expired_checksum_validation.positive?
    end

    def any_complete_moab_errors?
      num_complete_moab_not_ok.positive?
    end

    def num_complete_moab_not_ok
      # used multiple times, so memoize to avoid db queries
      @num_complete_moab_not_ok ||= CompleteMoab.count - CompleteMoab.ok.count
    end

    def num_preserved_objects
      # used multiple times, so memoize to avoid db queries
      @num_preserved_objects ||= PreservedObject.count
    end

    def preserved_object_highest_version
      preserved_object_ordered_version_counts.keys.last
    end

    # total number of object versions according to PreservedObject table
    def num_object_versions_per_preserved_object
      # used multiple times, so memoize to avoid db queries
      @num_object_versions_per_preserved_object ||= PreservedObject.sum(:current_version)
    end

    def average_version_per_preserved_object
      PreservedObject.pick(Arel.sql('SUM(current_version)::numeric/COUNT(id)')).round(2) unless num_preserved_objects.zero?
    end

    def num_complete_moabs
      # used multiple times; memoizing to avoid multiple db queries
      @num_complete_moabs ||= CompleteMoab.count
    end

    def complete_moab_highest_version
      complete_moab_ordered_version_counts.keys.last
    end

    # total number of object versions according to CompleteMoab table
    def num_object_versions_per_complete_moab
      # used multiple times, so memoize to avoid multiple db queries
      @num_object_versions_per_complete_moab ||= CompleteMoab.sum(:version)
    end

    def average_version_per_complete_moab
      # note, no user input to sanitize here, so ok to use Arel.sql
      # see https://api.rubyonrails.org/v7.0.4/classes/ActiveRecord/UnknownAttributeReference.html
      CompleteMoab.pick(Arel.sql('SUM(version)::numeric/COUNT(id)')).round(2) unless num_complete_moabs.zero?
    end

    def preserved_object_complete_moab_counts_match?
      num_preserved_objects == num_complete_moabs
    end

    def num_object_versions_preserved_object_complete_moab_match?
      num_object_versions_per_preserved_object == num_object_versions_per_complete_moab
    end

    def highest_version_preserved_object_complete_moab_match?
      preserved_object_highest_version == complete_moab_highest_version
    end

    private

    def preserved_object_ordered_version_counts
      # called multiple times, so memoize to avoid db queries
      @preserved_object_ordered_version_counts ||= PreservedObject.group(:current_version).count.sort.to_h
    end

    def complete_moab_ordered_version_counts
      # called multiple times, so memoize to avoid db queries
      @complete_moab_ordered_version_counts ||= CompleteMoab.group(:version).count.sort.to_h
    end

    # create this hash so we don't need to loop through storage_root_info multiple times
    def storage_root_totals # rubocop:disable Metrics/AbcSize
      @storage_root_totals ||=
        if storage_root_info.values.size.zero?
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
