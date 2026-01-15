# frozen_string_literal: true

module Show
  class ZippedMoabVersionComponent < ViewComponent::Base
    attr_reader :zipped_moab_version

    delegate :version, :created_at, :updated_at, :zip_endpoint, :zip_parts, to: :zipped_moab_version
    delegate :endpoint_name, :delivery_class, :endpoint_node, :storage_location, to: :zip_endpoint

    def initialize(zipped_moab_version:)
      @zipped_moab_version = zipped_moab_version
    end

    def render?
      zipped_moab_version.present?
    end
  end
end
