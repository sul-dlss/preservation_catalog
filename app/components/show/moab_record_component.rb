# frozen_string_literal: true

module Show
  class MoabRecordComponent < ViewComponent::Base
    attr_reader :moab_record

    delegate :version, :created_at, :updated_at, :last_moab_validation, :last_checksum_validation, :size, :status, :last_version_audit, :status_details, to: :moab_record

    def initialize(moab_record:)
      @moab_record = moab_record
    end

    def render?
      moab_record.present?
    end
  end
end
