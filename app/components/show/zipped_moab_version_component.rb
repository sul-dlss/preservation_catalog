# frozen_string_literal: true

module Show
  # Details about a ZippedMoabVersion
  class ZippedMoabVersionComponent < ViewComponent::Base
    attr_reader :zipped_moab_version

    delegate :id, :version, :created_at, :updated_at, :zip_endpoint, :zip_parts, :status, :status_updated_at, :status_details, :zip_parts_count,
             to: :zipped_moab_version
    delegate :endpoint_name, to: :zip_endpoint

    def initialize(zipped_moab_version:)
      @zipped_moab_version = zipped_moab_version
    end

    def render?
      zipped_moab_version.present?
    end
  end
end
