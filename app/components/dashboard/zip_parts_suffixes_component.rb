# frozen_string_literal: true

module Dashboard
  # methods for dashboard pertaining to ZipPartsSuffixesComponent
  class ZipPartsSuffixesComponent < ViewComponent::Base
    include Dashboard::ReplicationService

    def sorted_zip_parts_suffixes
      zip_part_suffixes.keys.sort_by { |s| s == '.zip' ? 0 : s.scan(/\d+/).first.to_i }
    end
  end
end
