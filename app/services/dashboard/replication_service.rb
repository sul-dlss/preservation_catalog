# frozen_string_literal: true

require 'action_view' # for number_to_human_size

# services for dashboard
module Dashboard
  # methods pertaining to replication functionality for dashboard
  class ReplicationService
    include ActionView::Helpers::NumberHelper # for number_to_human_size

    def replication_ok?
      endpoint_data.each do |_endpoint_name, info|
        return false if info[:replication_count] != CatalogService.new.num_object_versions_per_preserved_object
      end
      true
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
  end
end
