# frozen_string_literal: true

module Show
  # Warnings about a PreservedObject
  class WarningsComponent < ViewComponent::Base
    attr_reader :preserved_object, :druid

    Alert = Struct.new(:variant, :message)

    def initialize(preserved_object: nil, druid: nil)
      @preserved_object = preserved_object
      @druid = druid
    end

    def alerts
      [
        druid_alert,
        moab_record_alert,
        zipped_moab_version_alerts
      ].flatten.compact
    end

    private

    def druid_alert
      return if preserved_object.present?

      Alert.new('danger', "No Preserved Object found with druid #{druid}.")
    end

    def moab_record_alert
      return if preserved_object.blank? || preserved_object.moab_record&.status == 'ok'

      Alert.new('danger', moab_record_message)
    end

    def moab_record_message
      return 'No Moab Record found for this Preserved Object.' if preserved_object.moab_record.blank?

      "Moab Record status is '#{preserved_object.moab_record.status}'."
    end

    def zipped_moab_version_alerts
      return if preserved_object.blank?
      return zip_part_alerts if preserved_object.zipped_moab_versions.any?

      Alert.new('danger', 'No Zipped Moab Versions found for this Preserved Object.')
    end

    def zip_part_alerts
      preserved_object.zipped_moab_versions.filter_map do |zmv|
        next if zmv.zip_parts.any?

        Alert.new('warning', "Zipped Moab Version #{zmv.version} has no associated Zip Parts.")
      end
    end
  end
end
