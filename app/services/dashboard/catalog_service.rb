# frozen_string_literal: true

require 'action_view' # for number_to_human_size

# services for dashboard
module Dashboard
  # methods pertaining to catalog functionality for dashboard
  module CatalogService
    include ActionView::Helpers::NumberHelper # for number_to_human_size

    def moabs_on_storage_ok?
      moab_on_storage_counts_ok? && !any_complete_moab_errors?
    end

    def moab_on_storage_counts_ok?
      num_preserved_objects == num_complete_moabs &&
        num_object_versions_per_preserved_object == num_object_versions_per_complete_moab
    end

    def storage_root_info # rubocop:disable Metrics/AbcSize
      storage_root_info = {}
      MoabStorageRoot.all.each do |storage_root|
        storage_root_info[storage_root.name] =
          [
            storage_root.storage_location,
            number_to_human_size(storage_root.complete_moabs.sum(:size)),
            number_to_human_size(storage_root.complete_moabs.average(:size) || 0),
            storage_root.complete_moabs.count,
            CompleteMoab.statuses.keys.map { |status| storage_root.complete_moabs.where(status: status).count },
            storage_root.complete_moabs.fixity_check_expired.count
          ].flatten
      end
      storage_root_info
    end

    # @return [Array<Integer>] totals of counts from each storage root for:
    #   total of counts of each CompleteMoab status (ok, invalid_checksum, etc.)
    #   total of counts of fixity_check_expired
    #   total of complete_moab counts - this is last element in array due to index shift to skip storage_location and stored size
    def storage_root_totals # rubocop:disable Metrics/AbcSize
      return [0] if storage_root_info.values.size.zero?

      totals = Array.new(storage_root_info.values.first.size - 3, 0)
      storage_root_info.each_key do |root_name|
        storage_root_info[root_name][3..].each_with_index do |count, index|
          totals[index] += count
        end
      end
      totals
    end

    def storage_root_total_count
      storage_root_totals.first
    end

    def storage_root_total_ok_count
      storage_root_totals[1]
    end

    def complete_moab_total_size
      number_to_human_size(CompleteMoab.sum(:size))
    end

    def complete_moab_average_size
      number_to_human_size(CompleteMoab.average(:size)) unless num_complete_moabs.zero?
    end

    def complete_moab_status_counts
      CompleteMoab.statuses.keys.map { |status| CompleteMoab.where(status: status).count }
    end

    def status_labels
      CompleteMoab.statuses.keys.map { |status| status.tr('_', ' ') }
    end

    def num_expired_checksum_validation
      CompleteMoab.fixity_check_expired.count
    end

    def any_complete_moab_errors?
      num_complete_moab_not_ok.positive?
    end

    def num_complete_moab_not_ok
      CompleteMoab.where.not(status: 'ok').count
    end

    def num_preserved_objects
      PreservedObject.count
    end

    def preserved_object_highest_version
      preserved_object_ordered_version_counts.keys.last
    end

    # total number of object versions according to PreservedObject table
    def num_object_versions_per_preserved_object
      PreservedObject.sum(:current_version)
    end

    def average_version_per_preserved_object
      PreservedObject.pick(Arel.sql('SUM(current_version)::numeric/COUNT(id)')).round(2) unless num_preserved_objects.zero?
    end

    def num_complete_moabs
      CompleteMoab.count
    end

    def complete_moab_highest_version
      complete_moab_ordered_version_counts.keys.last
    end

    # total number of object versions according to CompleteMoab table
    def num_object_versions_per_complete_moab
      CompleteMoab.sum(:version)
    end

    def average_version_per_complete_moab
      # note, no user input to sanitize here, so ok to use Arel.sql
      # see https://api.rubyonrails.org/v7.0.4/classes/ActiveRecord/UnknownAttributeReference.html
      CompleteMoab.pick(Arel.sql('SUM(version)::numeric/COUNT(id)')).round(2) unless num_complete_moabs.zero?
    end

    private

    def preserved_object_ordered_version_counts
      PreservedObject.group(:current_version).count.sort.to_h
    end

    def complete_moab_ordered_version_counts
      CompleteMoab.group(:version).count.sort.to_h
    end
  end
end
