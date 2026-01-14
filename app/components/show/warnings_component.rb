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
        druid_alerts,
        moab_record_alert,
        zipped_moab_version_alerts
      ].flatten.compact
    end

    private

    def druid_alerts
      return if druid.blank? || preserved_object.present?

      Alert.new('danger', "No Preserved Object found with druid #{druid}.")
    end

    def moab_record_alert
      return if preserved_object.blank?

      if preserved_object.moab_record.present?
        return if preserved_object.moab_record.status == 'ok'

        return Alert.new('danger', "Moab Record status is '#{preserved_object.moab_record.status}'.")
      end

      Alert.new('danger', 'No Moab Record found for this Preserved Object.')
    end

    def zipped_moab_version_alerts
      return if preserved_object.blank?
      return zip_part_alerts if preserved_object.zipped_moab_versions.any?

      Alert.new('danger', 'No Zipped Moab Versions found for this Preserved Object.')
    end

    def zip_part_alerts
      preserved_object.zipped_moab_versions.map do |zmv|
        next unless zmv.zip_parts.empty?

        Alert.new('warning', "Zipped Moab Version #{zmv.version} has no associated Zip Parts.")
      end
    end
  end
end
