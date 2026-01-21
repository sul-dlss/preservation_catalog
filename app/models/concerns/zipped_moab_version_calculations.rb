# frozen_string_literal: true

# Methods for calculating aggregations on ZippedMoabVersions.
# These are separated from the main MoabRecord class for clarity.
module ZippedMoabVersionCalculations
  extend ActiveSupport::Concern
  include InstrumentationSupport

  STUCK_STATUSES = %w[created incomplete].freeze

  ZippedMoabVersionByZipEndpointResult = Struct.new('ZippedMoabVersionByZipEndpointResult',
                                                    :zip_endpoint,
                                                    :zipped_moab_version_count,
                                                    :ok_count,
                                                    :failed_count,
                                                    :created_count,
                                                    :incomplete_count,
                                                    keyword_init: true) do
    def initialize(**kwargs)
      super
      self.zipped_moab_version_count ||= 0
      self.ok_count ||= 0
      self.failed_count ||= 0
      self.created_count ||= 0
      self.incomplete_count ||= 0
    end
  end

  included do
    # @return [ActiveRecord::Relation<ZippedMoabVersion>] ZippedMoabVersions with failed status
    scope :with_errors, -> { where(status: 'failed').annotate(caller) }

    # @return [ActiveRecord::Relation<ZippedMoabVersion>] ZippedMoabVersions with status of incomplete or created for more than a week
    scope :stuck, lambda {
      where(status: STUCK_STATUSES)
        .where(status_updated_at: ...1.week.ago)
        .annotate(caller)
    }
  end

  class_methods do # rubocop:disable Metrics/BlockLength
    # @return [Integer] count of ZippedMoabVersions with status of created
    def created_count
      where(status: 'created')
        .annotate(caller)
        .count
    end

    # @return [Integer] count of ZippedMoabVersions with status of incomplete
    def incomplete_count
      where(status: 'incomplete')
        .annotate(caller)
        .count
    end

    # @return [Integer] count of missing ZippedMoabVersions
    def missing_count
      (PreservedObject.sum(:current_version) * ZipEndpoint.count) - count
    end

    # @return [Array<ZippedMoabVersionByZipEndpointResult>, ZippedMoabVersionByZipEndpointResult] aggregation of ZippedMoabVersions by ZipEndpoint
    #   and a total aggregation
    def zipped_moab_versions_by_zip_endpoint # rubocop:disable Metrics/AbcSize
      result_map = {}
      total_result = ZippedMoabVersionByZipEndpointResult.new(zipped_moab_version_count: 0)
      ZipEndpoint.find_each do |zip_endpoint|
        result_map[zip_endpoint.id] = ZippedMoabVersionByZipEndpointResult.new(
          zip_endpoint: zip_endpoint
        )
      end
      group(:zip_endpoint_id).count.each do |zip_endpoint_id, count|
        result_map[zip_endpoint_id].zipped_moab_version_count = count
        total_result.zipped_moab_version_count += count
      end
      group(:zip_endpoint_id, :status).count.each do |(zip_endpoint_id, status), count|
        count_method = "#{status}_count"
        result_map[zip_endpoint_id].public_send("#{count_method}=", count)
        total_count = total_result.public_send(count_method)
        total_result.public_send("#{count_method}=", total_count + count)
      end
      [result_map.values, total_result]
    end
  end
end
