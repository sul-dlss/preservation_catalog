# frozen_string_literal: true

require 'action_view' # for number_to_human_size

# services for dashboard
module Dashboard
  # methods pertaining to replication (cloud storage) tables in database for dashboard
  module ReplicationService
    include ActionView::Helpers::NumberHelper # for number_to_human_size
    include MoabOnStorageService

    def replication_and_zip_parts_ok?
      zip_parts_ok? && replication_ok?
    end

    def replication_ok?
      endpoint_data.each do |_endpoint_name, info|
        return false unless endpoint_replication_count_ok?(info[:replication_count])
      end
      true
    end

    def endpoint_replication_count_ok?(endpoint_replication_count)
      endpoint_replication_count == num_object_versions_per_preserved_object
    end

    def endpoint_data
      endpoint_data = {}
      ZipEndpoint.all.each do |zip_endpoint|
        endpoint_data[zip_endpoint.endpoint_name] =
          {
            delivery_class: zip_endpoint.delivery_class,
            replication_count: ZippedMoabVersion.where(zip_endpoint_id: zip_endpoint.id).count
          }
      end
      endpoint_data
    end

    def zip_part_suffixes
      ZipPart.group(:suffix).count
    end

    def zip_parts_total_size
      number_to_human_size(ZipPart.sum(:size))
    end

    def num_replication_errors
      ZipPart.where.not(status: 'ok').count
    end

    def zip_parts_ok?
      num_replication_errors.zero?
    end

    def zip_parts_unreplicated?
      ZipPart.unreplicated.count.positive?
    end

    def zip_parts_not_found?
      ZipPart.not_found.count.positive?
    end

    def zip_parts_replicated_checksum_mismatch?
      ZipPart.replicated_checksum_mismatch.count.positive?
    end
  end
end
