# frozen_string_literal: true

module Show
  # Details about a ZipPart
  class ZipPartComponent < ViewComponent::Base
    attr_reader :zip_part

    delegate :id, :size, :md5, :created_at, :updated_at, to: :zip_part

    def initialize(zip_part:)
      @zip_part = zip_part
    end

    def render?
      zip_part.present?
    end
  end
end
