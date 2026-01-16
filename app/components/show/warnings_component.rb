# frozen_string_literal: true

module Show
  # Warnings about a PreservedObject
  class WarningsComponent < ViewComponent::Base
    attr_reader :preserved_object

    Alert = Struct.new(:variant, :message)

    def initialize(preserved_object:)
      @preserved_object = preserved_object
    end

    def alerts
      alerts = []
      alerts << Alert.new('danger', 'No Moab Record found for this Preserved Object.') if preserved_object.moab_record.nil?
      alerts << Alert.new('danger', 'No Zipped Moab Versions found for this Preserved Object.') if preserved_object.zipped_moab_versions.empty?
      preserved_object.zipped_moab_versions.each do |zmv|
        alerts << Alert.new('warning', "Zipped Moab Version #{zmv.version} has no associated Zip Parts.") if zmv.zip_parts.empty?
      end
      alerts
    end
  end
end
