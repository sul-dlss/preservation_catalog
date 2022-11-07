# frozen_string_literal: true

# helper methods for dashboard pertaining to replication functionality
module DashboardReplicationHelper
  def replication_ok?
    replication_info.each_value do |info|
      return false if info[1] != num_object_versions_per_preserved_object
    end
    true
  end

  def replication_info
    replication_info = {}
    ZipEndpoint.all.each do |zip_endpoint|
      replication_info[zip_endpoint.endpoint_name] =
        [
          zip_endpoint.delivery_class,
          ZippedMoabVersion.where(zip_endpoint_id: zip_endpoint.id).count
        ].flatten
    end
    replication_info
  end

  def zip_part_suffixes
    ZipPart.group(:suffix).count
  end

  def zip_parts_total_size
    "#{ZipPart.sum(:size).fdiv(Numeric::TERABYTE).round(2)} Tb"
  end

  def num_replication_errors
    ZipPart.count - ZipPart.ok.count
  end
end
