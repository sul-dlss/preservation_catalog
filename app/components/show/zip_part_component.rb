# frozen_string_literal: true

module Show
  # Details about a ZipPart
  class ZipPartComponent < ViewComponent::Base
    attr_reader :zip_part

    delegate :size, :md5, :created_at, :updated_at, :create_info, :status, :last_existence_check, :last_checksum_validation, to: :zip_part

    def initialize(zip_part:)
      @zip_part = zip_part
    end

    def render?
      zip_part.present?
    end
  end
end
