# frozen_string_literal: true

module Show
  # Details about a MoabRecord
  class MoabRecordComponent < ViewComponent::Base
    attr_reader :moab_record

    delegate :version, :created_at, :updated_at, :last_moab_validation,
             :last_checksum_validation, :size, :status, :last_version_audit,
             :status_details, :moab_storage_root, to: :moab_record

    def initialize(moab_record:)
      @moab_record = moab_record
    end

    def render?
      moab_record.present?
    end
  end
end
