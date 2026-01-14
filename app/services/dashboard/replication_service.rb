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

    def replication_and_zipped_moab_versions_ok?
      replication_ok? && !zipped_moab_versions_failed?
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
      PreservedObject.annotate(caller).sum(:current_version)
    end

    # Array-ify the endpoint data so it's renderable via the ViewComponent `#with_collection` method
    def endpoints
      endpoint_data.to_a
    end

    def endpoint_data
      # called multiple times, so memoize to avoid db queries
      @endpoint_data ||= {}.tap do |endpoint_data|
        replication_counts = ZippedMoabVersion.group(:zip_endpoint_id).annotate(caller).count
        ZipEndpoint.find_each do |zip_endpoint|
          endpoint_data[zip_endpoint.endpoint_name] =
            {
              replication_count: replication_counts.fetch(zip_endpoint.id, 0)
            }
        end
      end
    end

    def zipped_moab_versions_incomplete_count
      ZippedMoabVersion.incomplete.annotate(caller).count
    end

    def zipped_moab_versions_incomplete?
      zipped_moab_versions_incomplete_count.positive?
    end

    def zipped_moab_versions_failed?
      zipped_moab_versions_failed_count.positive?
    end

    def zipped_moab_versions_failed_count
      ZippedMoabVersion.failed.annotate(caller).count
    end
  end
end
