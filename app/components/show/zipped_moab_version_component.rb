# frozen_string_literal: true

module Show
  # Details about a ZippedMoabVersion
  class ZippedMoabVersionComponent < ViewComponent::Base
    attr_reader :zipped_moab_version

    delegate :id, :version, :created_at, :updated_at, :zip_endpoint, :zip_parts, to: :zipped_moab_version
    delegate :endpoint_name, :endpoint_node, :storage_location, to: :zip_endpoint

    def initialize(zipped_moab_version:)
      @zipped_moab_version = zipped_moab_version
    end

    def render?
      zipped_moab_version.present?
    end
  end
end
