# frozen_string_literal: true

# Base job for this Application
class ApplicationJob < ActiveJob::Base
  before_perform do |_job|
    ActiveRecord::Base.clear_active_connections!
  end

  # Raises if the metadata is incomplete
  # @param [Hash<Symbol => String>] metadata
  # @option metadata [String] :checksum_md5
  # @option metadata [Integer] :size
  # @option metadata [Integer] :parts_count
  # @option metadata [String] :suffix
  # @option metadata [String] :zip_cmd
  # @option metadata [String] :zip_version
  def zip_info_check!(metadata)
    raise ArgumentError, 'metadata Hash not found' if metadata.blank?

    %i[checksum_md5 size zip_cmd zip_version].each do |key|
      raise ArgumentError, "Required metadata[:#{key}] not found" if metadata[key].blank?
    end
  end
end
