# creating a PreservedObject and/or updating check timestamps may require interactions
#  beyond the single PreservedObject model (e.g. PreservedCopy, PreservationPolicy).
#  This service class encapsulates logic to keep the controller and the model object
#    code simpler/thinner.
# NOTE: performing validation here to allow this class to be called directly avoiding http overhead
#
# inspired by http://www.thegreatcodeadventure.com/smarter-rails-services-with-active-record-modules/
class PreservedObjectHandler

  require 'audit_results.rb'

  include ActiveModel::Validations

  # Note: supplying validations here to allow validation before use, e.g. incoming_version in numeric logic
  validates :druid, presence: true, format: { with: DruidTools::Druid.pattern }
  validates :incoming_version, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :incoming_size, numericality: { only_integer: true, greater_than: 0 }
  validates_each :endpoint do |record, attr, value|
    record.errors.add(attr, 'must be an actual Endpoint') unless value.is_a?(Endpoint)
  end

  attr_reader :druid, :incoming_version, :incoming_size, :endpoint, :handler_results

  delegate :storage_location, to: :endpoint

  def initialize(druid, incoming_version, incoming_size, endpoint)
    @druid = druid
    @incoming_version = version_string_to_int(incoming_version)
    @incoming_size = string_to_int(incoming_size)
    @endpoint = endpoint
    @handler_results = AuditResults.new(druid, incoming_version, endpoint)
  end

  def create_after_validation
    handler_results.check_name = 'create_after_validation'
    if invalid?
      handler_results.add_result(AuditResults::INVALID_ARGUMENTS, errors.full_messages)
    elsif PreservedObject.exists?(druid: druid)
      handler_results.add_result(AuditResults::DB_OBJ_ALREADY_EXISTS, 'PreservedObject')
    elsif moab_validation_errors.empty?
      create_db_objects(PreservedCopy::OK_STATUS)
    else
      create_db_objects(PreservedCopy::INVALID_MOAB_STATUS)
    end

    handler_results.report_results
  end

  def create
    handler_results.check_name = 'create'
    if invalid?
      handler_results.add_result(AuditResults::INVALID_ARGUMENTS, errors.full_messages)
    elsif PreservedObject.exists?(druid: druid)
      handler_results.add_result(AuditResults::DB_OBJ_ALREADY_EXISTS, 'PreservedObject')
    else
      create_db_objects(PreservedCopy::VALIDITY_UNKNOWN_STATUS)
    end

    handler_results.report_results
  end

  # this is a long, complex method (shameless green); if it is refactored, revisit the exceptions in rubocop.yml
  def check_existence
    handler_results.check_name = 'check_existence'
    if invalid?
      handler_results.add_result(AuditResults::INVALID_ARGUMENTS, errors.full_messages)
    elsif PreservedObject.exists?(druid: druid)
      Rails.logger.debug "check_existence #{druid} called"
      if endpoint.endpoint_type.endpoint_class == 'online'
        transaction_ok = with_active_record_transaction_and_rescue do
          pres_object = PreservedObject.find_by!(druid: druid)
          # FIXME: what if there is more than one associated pres_copy?
          pres_copy = PreservedCopy.find_by!(preserved_object: pres_object, endpoint: endpoint) if pres_object

          raise_rollback_if_pc_po_version_mismatch(pres_copy)

          if incoming_version == pres_copy.version
            set_status_as_seen_on_disk(pres_copy, true) unless pres_copy.status == PreservedCopy::OK_STATUS
            handler_results.add_result(AuditResults::VERSION_MATCHES, 'PreservedCopy')
          elsif incoming_version > pres_copy.version
            set_status_as_seen_on_disk(pres_copy, true) unless pres_copy.status == PreservedCopy::OK_STATUS
            handler_results.add_result(AuditResults::ACTUAL_VERS_GT_DB_OBJ, db_obj_name: 'PreservedCopy', db_obj_version: pres_copy.version)
            if moab_validation_errors.empty?
              pres_copy.upd_audstamps_version_size(ran_moab_validation?, incoming_version, incoming_size)
              pres_object.current_version = incoming_version
              pres_object.save!
            else
              update_status(pres_copy, PreservedCopy::INVALID_MOAB_STATUS)
            end
          else # incoming_version < pres_copy.version
            set_status_as_seen_on_disk(pres_copy, false)
            handler_results.add_result(AuditResults::ACTUAL_VERS_LT_DB_OBJ, db_obj_name: 'PreservedCopy', db_obj_version: pres_copy.version)
          end
          pres_copy.update_audit_timestamps(ran_moab_validation?, true)
          pres_copy.save!
        end
        handler_results.remove_db_updated_results unless transaction_ok
      elsif endpoint.endpoint_type.endpoint_class == 'archive'
        # TODO: note that an endpoint PC version might not match PO.current_version
      end
    else
      handler_results.add_result(AuditResults::DB_OBJ_DOES_NOT_EXIST, 'PreservedObject')
      if moab_validation_errors.empty?
        create_db_objects(PreservedCopy::OK_STATUS)
      else
        create_db_objects(PreservedCopy::INVALID_MOAB_STATUS)
      end
    end
    handler_results.report_results
  end

  def confirm_version
    handler_results.check_name = 'confirm_version'
    if invalid?
      handler_results.add_result(AuditResults::INVALID_ARGUMENTS, errors.full_messages)
    else
      Rails.logger.debug "confirm_version #{druid} called"
      if endpoint.endpoint_type.endpoint_class == 'online'
        # NOTE: we deal with active record transactions in confirm_online_version, not here
        confirm_online_version
      elsif endpoint.endpoint_type.endpoint_class == 'archive'
        # TODO: note that an endpoint PC version might not match PO.current_version
      end
    end

    handler_results.report_results
  end

  def update_version_after_validation
    handler_results.check_name = 'update_version_after_validation'
    if invalid?
      handler_results.add_result(AuditResults::INVALID_ARGUMENTS, errors.full_messages)
    else
      Rails.logger.debug "update_version_after_validation #{druid} called"
      if endpoint.endpoint_type.endpoint_class == 'online'
        if moab_validation_errors.empty?
          # NOTE: we deal with active record transactions in update_online_version, not here
          update_online_version(PreservedCopy::OK_STATUS)
        else
          update_pc_invalid_moab
        end
      elsif endpoint.endpoint_type.endpoint_class == 'archive'
        # TODO: perform archive object validation; then create a new PC record for the new
        #  archived version on the endpoint
      end
    end

    handler_results.report_results
  end

  def update_version
    handler_results.check_name = 'update_version'
    if invalid?
      handler_results.add_result(AuditResults::INVALID_ARGUMENTS, errors.full_messages)
    else
      Rails.logger.debug "update_version #{druid} called"
      if endpoint.endpoint_type.endpoint_class == 'online'
        # NOTE: we deal with active record transactions in update_online_version, not here
        update_online_version(nil, true)
      elsif endpoint.endpoint_type.endpoint_class == 'archive'
        # TODO: create a new PC record for the new archived version on the endpoint
      end
    end

    handler_results.report_results
  end

  private

  # TODO: near duplicate of method in catalog_to_moab - extract superclass or moab wrapper class??
  def moab_validation_errors
    @moab_errors ||=
      begin
        object_dir = "#{storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}"
        moab = Moab::StorageObject.new(druid, object_dir)
        object_validator = Stanford::StorageObjectValidator.new(moab)
        moab_errors = object_validator.validation_errors(Settings.moab.allow_content_subdirs)
        @ran_moab_validation = true
        if moab_errors.any?
          moab_error_msgs = []
          moab_errors.each do |error_hash|
            error_hash.each_value { |msg| moab_error_msgs << msg }
          end
          handler_results.add_result(AuditResults::INVALID_MOAB, moab_error_msgs)
        end
        moab_errors
      end
  end

  # TODO: duplicate of method in catalog_to_moab - extract superclass or moab wrapper class??
  def ran_moab_validation?
    @ran_moab_validation ||= false
  end

  def create_db_objects(status)
    pp_default_id = PreservationPolicy.default_policy_id
    transaction_ok = with_active_record_transaction_and_rescue do
      po = PreservedObject.create!(druid: druid,
                                   current_version: incoming_version,
                                   preservation_policy_id: pp_default_id)
      pc_attrs = {
        preserved_object: po,
        version: incoming_version,
        size: incoming_size,
        endpoint: endpoint,
        status: status
      }
      if ran_moab_validation?
        t = Time.current
        pc_attrs[:last_version_audit] = t
        pc_attrs[:last_moab_validation] = t
      end
      PreservedCopy.create!(pc_attrs)
    end

    handler_results.add_result(AuditResults::CREATED_NEW_OBJECT) if transaction_ok
  end

  # TODO: this is "too complex" per rubocop: shameless green implementation
  # NOTE: if we can reduce complexity, remove Metrics/PerceivedComplexity exception in .rubocop.yml
  def update_online_version(status=nil, set_status_to_unexp_version=false)
    transaction_ok = with_active_record_transaction_and_rescue do
      pres_object = PreservedObject.find_by!(druid: druid)
      pres_copy = PreservedCopy.find_by!(preserved_object: pres_object, endpoint: endpoint) if pres_object

      raise_rollback_if_pc_po_version_mismatch(pres_copy)

      # FIXME: what if there is more than one associated pres_copy?
      if incoming_version > pres_copy.version && pres_copy.matches_po_current_version?
        # add results without db updates
        code = AuditResults::ACTUAL_VERS_GT_DB_OBJ
        handler_results.add_result(code, db_obj_name: 'PreservedCopy', db_obj_version: pres_copy.version)

        pres_copy.upd_audstamps_version_size(ran_moab_validation?, incoming_version, incoming_size)
        update_status(pres_copy, status) if status && ran_moab_validation?
        pres_copy.save!
        pres_object.current_version = incoming_version
        pres_object.save!
      else
        if set_status_to_unexp_version
          status = PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
        end
        update_pc_unexpected_version(pres_copy, status)
      end
    end

    handler_results.remove_db_updated_results unless transaction_ok
  end

  def raise_rollback_if_pc_po_version_mismatch(pres_copy)
    unless pres_copy.matches_po_current_version?
      pc_version = pres_copy.version
      po_version = pres_copy.preserved_object.current_version
      res_code = AuditResults::PC_PO_VERSION_MISMATCH
      handler_results.add_result(res_code, { pc_version: pc_version, po_version: po_version })
      raise ActiveRecord::Rollback, "PreservedCopy version #{pc_version} != PreservedObject current_version #{po_version}"
    end
  end

  def update_pc_invalid_moab
    transaction_ok = with_active_record_transaction_and_rescue do
      pres_object = PreservedObject.find_by!(druid: druid)
      pres_copy = PreservedCopy.find_by!(preserved_object: pres_object, endpoint: endpoint) if pres_object
      # FIXME: what if there is more than one associated pres_copy?
      update_status(pres_copy, PreservedCopy::INVALID_MOAB_STATUS)
      pres_copy.update_audit_timestamps(ran_moab_validation?, false)
      pres_copy.save!
    end
    handler_results.remove_db_updated_results unless transaction_ok
  end

  # given a PreservedCopy instance and whether the caller found the expected version of it on disk, this will perform
  # other validations of what's on disk, and will update the status accordingly
  # TODO: near duplicate of method in CatalogToMoab - extract superclass or moab wrapper class??
  def set_status_as_seen_on_disk(pres_copy, found_expected_version)
    if moab_validation_errors.any?
      update_status(pres_copy, PreservedCopy::INVALID_MOAB_STATUS)
      return
    end

    unless found_expected_version
      update_status(pres_copy, PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS)
      return
    end

    # TODO: do the check that'd set INVALID_CHECKSUM_STATUS

    update_status(pres_copy, PreservedCopy::OK_STATUS)
  end

  def update_pc_unexpected_version(pres_copy, new_status)
    handler_results.add_result(AuditResults::UNEXPECTED_VERSION, db_obj_name: 'PreservedCopy', db_obj_version: pres_copy.version)
    version_comparison_results(pres_copy, pres_copy.version)

    update_status(pres_copy, new_status) if new_status
    pres_copy.update_audit_timestamps(ran_moab_validation?, true)
    pres_copy.save!
  end

  # shameless green implementation
  def confirm_online_version
    transaction_ok = with_active_record_transaction_and_rescue do
      pres_object = PreservedObject.find_by!(druid: druid)
      # FIXME: what if there is more than one associated pres_copy?
      pres_copy = PreservedCopy.find_by!(preserved_object: pres_object, endpoint: endpoint) if pres_object

      raise_rollback_if_pc_po_version_mismatch(pres_copy)

      if incoming_version == pres_copy.version
        set_status_as_seen_on_disk(pres_copy, true) unless pres_copy.status == PreservedCopy::OK_STATUS
        handler_results.add_result(AuditResults::VERSION_MATCHES, 'PreservedCopy')
      else
        set_status_as_seen_on_disk(pres_copy, false)
        handler_results.add_result(AuditResults::UNEXPECTED_VERSION, db_obj_name: 'PreservedCopy', db_obj_version: pres_copy.version)
      end
      pres_copy.update_audit_timestamps(ran_moab_validation?, true)
      pres_copy.save!
    end
    handler_results.remove_db_updated_results unless transaction_ok
  end

  # performs passed code wrapped in ActiveRecord transaction via yield
  # @return true if transaction completed without error; false if ActiveRecordError was raised
  def with_active_record_transaction_and_rescue
    begin
      ApplicationRecord.transaction { yield }
      return true
    rescue ActiveRecord::RecordNotFound => e
      handler_results.add_result(AuditResults::DB_OBJ_DOES_NOT_EXIST, e.inspect)
    rescue ActiveRecord::ActiveRecordError => e
      handler_results.add_result(
        AuditResults::DB_UPDATE_FAILED, "#{e.inspect} #{e.message} #{e.backtrace.inspect}"
      )
    end
    false
  end

  # expects @incoming_version to be numeric
  def version_comparison_results(db_object, db_version)
    if incoming_version == db_version
      handler_results.add_result(AuditResults::VERSION_MATCHES, db_object.class.name)
    elsif incoming_version < db_version
      handler_results.add_result(
        AuditResults::ACTUAL_VERS_LT_DB_OBJ,
        { db_obj_name: db_object.class.name, db_obj_version: db_version }
      )
    elsif incoming_version > db_version
      handler_results.add_result(
        AuditResults::ACTUAL_VERS_GT_DB_OBJ,
        { db_obj_name: db_object.class.name, db_obj_version: db_version }
      )
    end
  end

  # TODO: near duplicate of method in catalog_to_moab - extract superclass or moab wrapper class??
  def update_status(preserved_copy, new_status)
    preserved_copy.update_status(new_status) do
      handler_results.add_result(
        AuditResults::PC_STATUS_CHANGED,
        { old_status: preserved_copy.status, new_status: new_status }
      )
    end
  end

  def version_string_to_int(val)
    result = string_to_int(val)
    return result if result.instance_of?(Integer)
    # accommodate 'vnnn' strings from Moab version directories
    return val[1..-1].to_i if val.instance_of?(String) && val.match(/^v\d+$/)
    val
  end

  def string_to_int(val)
    return if val.blank?
    return val if val.instance_of?(Integer) # NOTE: negative integers caught with validation
    return val.to_i if val.instance_of?(String) && val.scan(/\D/).empty?
    val
  end
end
