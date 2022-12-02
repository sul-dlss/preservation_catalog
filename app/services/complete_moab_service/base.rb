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

    def initialize(druid:, incoming_version:, incoming_size:, moab_storage_root:, check_name:)
      @druid = druid
      @incoming_version = ApplicationController.helpers.version_string_to_int(incoming_version)
      @incoming_size = ApplicationController.helpers.string_to_int(incoming_size)
      @moab_storage_root = moab_storage_root
      @results = AuditResults.new(druid: druid, actual_version: incoming_version, moab_storage_root: moab_storage_root, check_name: check_name)
      @logger = PreservationCatalog::Application.logger
    end

    def preserved_object
      @preserved_object ||= PreservedObject.find_by!(druid: druid)
    end

    def complete_moab
      # There should be at most one CompleteMoab for a given druid on a given storage location:
      # * At the DB level, there's a unique index on druid for preserved_objects, a unique index on storage_location
      # for moab_storage_roots, and a unique index on the combo of preserved_object_id and moab_storage_root_id for
      # complete_moabs.
      # * A moab always lives in the druid tree path of the storage_location, so there is only one
      # possible moab path for any given druid in a given storage root.
      @complete_moab ||= CompleteMoab.joins(:preserved_object, :moab_storage_root).find_by!(
        preserved_objects: { druid: druid }, moab_storage_roots: { storage_location: storage_location }
      )
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

    def status_handler
      @status_handler ||= StatusHandler.new(audit_results: results, complete_moab: complete_moab)
    end

    def moab_on_storage_validator
      @moab_on_storage_validator ||= MoabOnStorage::Validator.new(moab: moab_on_storage, audit_results: results)
    end

    def moab_on_storage
      @moab_on_storage ||= MoabOnStorage.moab(druid: druid, storage_location: storage_location)
    end

    # this wrapper reads a little nicer in this class, since CompleteMoabHandler is always doing this the same way
    def with_active_record_transaction_and_rescue
      transaction_ok = ActiveRecordUtils.with_transaction_and_rescue(results) { yield }
      results.remove_db_updated_results unless transaction_ok
      transaction_ok
    end

    def raise_rollback_if_version_mismatch
      return if complete_moab.matches_po_current_version?

      results.add_result(AuditResults::CM_PO_VERSION_MISMATCH, cm_version: complete_moab_version, po_version: preserved_object_version)
      raise ActiveRecord::Rollback, "CompleteMoab version #{complete_moab_version} != PreservedObject current_version #{preserved_object_version}"
    end

    def complete_moab_version
      complete_moab.version
    end

    def preserved_object_version
      complete_moab.preserved_object.current_version
    end

    # Note that this may be called by running M2C on a storage root and discovering a second copy of a Moab,
    #   or maybe by calling #create_after_validation directly after copying a Moab
    def create_db_objects(status, checksums_validated: false)
      transaction_ok = with_active_record_transaction_and_rescue do
        preserved_object = create_preserved_object
        preserved_object.create_complete_moab!(complete_moab_attrs(status, checksums_validated))
      end
      results.add_result(AuditResults::CREATED_NEW_OBJECT) if transaction_ok
    end

    def report_results!
      AuditResultsReporter.report_results(audit_results: results)
    end

    def complete_moab_exists?
      CompleteMoab.by_druid(druid).by_storage_root(moab_storage_root).exists?
    end

    def validation_errors?
      moab_on_storage_validator.moab_validation_errors.present?
    end

    def create_missing_complete_moab
      results.add_result(AuditResults::DB_OBJ_DOES_NOT_EXIST, 'CompleteMoab')
      status = moab_on_storage_validator.moab_validation_errors.empty? ? 'validity_unknown' : 'invalid_moab'
      create_db_objects(status)
    end

    private

    def complete_moab_attrs(status, checksums_validated)
      {
        version: incoming_version,
        size: incoming_size,
        moab_storage_root: moab_storage_root,
        status: status
      }.tap do |attrs|
        time = Time.current
        if moab_on_storage_validator.ran_moab_validation?
          attrs[:last_version_audit] = time
          attrs[:last_moab_validation] = time
        end
        attrs[:last_checksum_validation] = time if checksums_validated
      end
    end

    def create_preserved_object
      PreservedObject.find_or_create_by!(druid: druid) do |preserved_object|
        preserved_object.current_version = incoming_version # init to match version of the first moab for the druid
      end
    end
  end
end
