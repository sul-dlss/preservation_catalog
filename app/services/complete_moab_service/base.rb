# frozen_string_literal: true

module CompleteMoabService
  # Base class for CompleteMoab services.
  class Base
    include ActiveModel::Validations

    validates :druid, presence: true, format: { with: DruidTools::Druid.pattern }
    validates :incoming_version, presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates :incoming_size, numericality: { only_integer: true, greater_than: 0 }
    validates_each :moab_storage_root do |record, attr, value|
      record.errors.add(attr, 'must be an actual MoabStorageRoot') unless value.is_a?(MoabStorageRoot)
    end

    attr_reader :druid, :incoming_version, :incoming_size, :moab_storage_root, :results
    attr_writer :logger

    delegate :storage_location, to: :moab_storage_root
    delegate :complete_moab, to: :moab_validator

    def initialize(druid:, incoming_version:, incoming_size:, moab_storage_root:, check_name:)
      @druid = druid
      @incoming_version = ApplicationController.helpers.version_string_to_int(incoming_version)
      @incoming_size = ApplicationController.helpers.string_to_int(incoming_size)
      @moab_storage_root = moab_storage_root
      @results = AuditResults.new(druid: druid, actual_version: incoming_version, moab_storage_root: moab_storage_root, check_name: check_name)
      @logger = PreservationCatalog::Application.logger
    end

    def pres_object
      @pres_object ||= PreservedObject.find_by!(druid: druid)
    end

    protected

    # perform_execute wraps with common parts of the execute method for all complete moab services
    def perform_execute
      if invalid?
        results.add_result(AuditResults::INVALID_ARGUMENTS, errors.full_messages)
      elsif block_given?
        yield
      end

      report_results!
      results
    end

    def moab_validator
      @moab_validator ||= MoabValidator.new(druid: druid, storage_location: storage_location, results: results)
    end

    # this wrapper reads a little nicer in this class, since CompleteMoabHandler is always doing this the same way
    def with_active_record_transaction_and_rescue
      ActiveRecordUtils.with_transaction_and_rescue(results) { yield }
    end

    def raise_rollback_if_cm_po_version_mismatch
      return unless primary_moab?

      return if complete_moab.matches_po_current_version?

      cm_version = complete_moab.version
      po_version = complete_moab.preserved_object.current_version
      res_code = AuditResults::CM_PO_VERSION_MISMATCH
      results.add_result(res_code, cm_version: cm_version, po_version: po_version)
      raise ActiveRecord::Rollback, "CompleteMoab version #{cm_version} != PreservedObject current_version #{po_version}"
    end

    def primary_moab?
      @primary_moab ||= complete_moab.primary?
    end

    # Note that this may be called by running M2C on a storage root and discovering a second copy of a Moab,
    #   or maybe by calling #create_after_validation directly after copying a Moab
    def create_db_objects(status, checksums_validated: false)
      cm_attrs = {
        version: incoming_version,
        size: incoming_size,
        moab_storage_root: moab_storage_root,
        status: status
      }
      t = Time.current
      if moab_validator.ran_moab_validation?
        cm_attrs[:last_version_audit] = t
        cm_attrs[:last_moab_validation] = t
      end
      cm_attrs[:last_checksum_validation] = t if checksums_validated
      ppid = PreservationPolicy.default_policy.id

      # TODO: remove tests' dependence on 2 "create!" calls, use single built-in AR transactionality
      transaction_ok = with_active_record_transaction_and_rescue do
        this_po = PreservedObject
                  .find_or_create_by!(druid: druid) do |po|
                    po.current_version = incoming_version # init to match version of the first moab for the druid
                    po.preservation_policy_id = ppid
                  end
        this_cm = this_po.create_complete_moab!(cm_attrs)
        # add to join table unless there is already a primary moab
        PreservedObjectsPrimaryMoab.find_or_create_by!(preserved_object: this_po) { |popm| popm.complete_moab = this_cm }
      end
      results.add_result(AuditResults::CREATED_NEW_OBJECT) if transaction_ok
    end

    def report_results!
      AuditResultsReporter.report_results(audit_results: results)
    end
  end
end
