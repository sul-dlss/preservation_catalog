# frozen_string_literal: true

module Show
  # Details about a PreservedObject
  class DetailsComponent < ViewComponent::Base
    attr_reader :preserved_object

    delegate :druid, :current_version, :created_at, :updated_at, :last_archive_audit, :robot_versioning_allowed, to: :preserved_object

    def initialize(preserved_object:)
      @preserved_object = preserved_object
    end
  end
end
