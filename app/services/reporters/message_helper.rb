# frozen_string_literal: true

module Reporters
  # Helper for formatting messages.
  class MessageHelper
    def self.invalid_moab_message(check_name, version, moab_storage_root, result)
      "#{string_prefix(check_name, version, moab_storage_root)} || #{result.values.first}"
    end

    def self.results_as_message(check_name, version, moab_storage_root, results)
      "#{string_prefix(check_name, version, moab_storage_root)} #{results.map(&:values).flatten.join(' && ')}"
    end

    def self.string_prefix(check_name, version, moab_storage_root)
      location_info = "actual location: #{moab_storage_root.name}" if moab_storage_root
      actual_version_info = "actual version: #{version}" if version
      "#{check_name} (#{location_info}; #{actual_version_info})"
    end
  end
end
