# frozen_string_literal: true

module Show
  # Renders the zip part info debug information in a table
  class ZipPartInfoComponent < ViewComponent::Base
    attr_reader :zip_part_info

    def initialize(zip_part_info:)
      @zip_part_info = zip_part_info
    end

    def render?
      zip_part_info.present?
    end
  end
end
