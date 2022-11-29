# frozen_string_literal: true

# TODO: this will be going away in favor of Dashboard::ReplicationService and ViewComponents

# helper methods for dashboard pertaining to replication functionality
module DashboardReplicationHelper
  # used by replication_status partials
  def replication_ok?
    endpoint_data.each do |_endpoint_name, info|
      return false if info[:replication_count] != num_object_versions_per_preserved_object
    end
    true
  end

  # used by replication_status partials
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

  # used by replication_status partials
  def num_replication_errors
    ZipPart.where.not(status: 'ok').count
  end

  def zip_parts_ok?
    num_replication_errors.zero?
  end
end
