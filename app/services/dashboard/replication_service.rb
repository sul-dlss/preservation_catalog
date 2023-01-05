# frozen_string_literal: true

require 'action_view' # for number_to_human_size

# services for dashboard
module Dashboard
  # methods pertaining to replication (cloud storage) tables in database for dashboard
  module ReplicationService
    include ActionView::Helpers::NumberHelper # for number_to_human_size
    include InstrumentationSupport

    def replication_and_zip_parts_ok?
      zip_parts_ok? && replication_ok?
    end

    def replication_ok?
      @replication_ok ||= endpoint_data.values.all? do |info|
        endpoint_replication_count_ok?(info[:replication_count])
      end
    end

    def endpoint_replication_count_ok?(endpoint_replication_count)
      endpoint_replication_count == num_object_versions_per_preserved_object
    end

    # total number of object versions according to PreservedObject table
    def num_object_versions_per_preserved_object
      PreservedObject.all.annotate(caller).sum(:current_version)
    end

    def endpoint_data
      # called multiple times, so memoize to avoid db queries
      @endpoint_data ||= {}.tap do |endpoint_data|
        replication_counts = ZippedMoabVersion.group(:zip_endpoint_id).annotate(caller).count
        ZipEndpoint.all.each do |zip_endpoint|
          endpoint_data[zip_endpoint.endpoint_name] =
            {
              delivery_class: zip_endpoint.delivery_class,
              replication_count: replication_counts.fetch(zip_endpoint.id, 0)
            }
        end
      end
    end

    def zip_part_suffixes
      # called multiple times, so memoize to avoid db queries
      @zip_part_suffixes ||= ZipPart.group(:suffix).annotate(caller).count
    end

    def zip_parts_total_size
      number_to_human_size(ZipPart.all.annotate(caller).sum(:size))
    end

    def num_replication_errors
      # This is faster than querying .where.not(status: 'ok')
      ZipPart.where(status: replication_error_statuses).annotate(caller).count
    end

    def replication_error_statuses
      ZipPart.statuses.keys.excluding('ok')
    end

    def zip_parts_ok?
      !ZipPart.where(status: replication_error_statuses).annotate(caller).exists?
    end

    def zip_parts_unreplicated?
      ZipPart.unreplicated.annotate(caller).count.positive?
    end

    def zip_parts_not_found?
      ZipPart.not_found.annotate(caller).count.positive?
    end

    def zip_parts_replicated_checksum_mismatch?
      ZipPart.replicated_checksum_mismatch.annotate(caller).count.positive?
    end
  end
end
