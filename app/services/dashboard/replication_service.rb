# frozen_string_literal: true

# services for dashboard
module Dashboard
  # methods pertaining to replication (cloud storage) tables in database for dashboard
  module ReplicationService
    include InstrumentationSupport

    OK_BADGE_CLASS = 'bg-success'
    NOT_OK_BADGE_CLASS = 'bg-danger'
    OK_LABEL = 'OK'
    NOT_OK_LABEL = 'Error'

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

    # Array-ify the endpoint data so it's renderable via the ViewComponent `#with_collection` method
    def endpoints
      endpoint_data.to_a
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

    def zip_parts_unreplicated_count
      ZipPart.unreplicated.annotate(caller).count
    end

    def zip_parts_unreplicated?
      zip_parts_unreplicated_count.positive?
    end

    def zip_parts_not_found_count
      ZipPart.not_found.annotate(caller).count
    end

    def zip_parts_not_found?
      zip_parts_not_found_count.positive?
    end

    def zip_parts_replicated_checksum_mismatch_count
      ZipPart.replicated_checksum_mismatch.annotate(caller).count
    end

    def zip_parts_replicated_checksum_mismatch?
      zip_parts_replicated_checksum_mismatch_count.positive?
    end
  end
end
