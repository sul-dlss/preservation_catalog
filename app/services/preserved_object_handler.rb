# creating a PreservedObject and/or updating check timestamps may require interactions
#  beyond the single PreservedObject model (e.g. PreservedCopy, PreservationPolicy).
#  This service class encapsulates logic to keep the controller and the model object
#    code simpler/thinner.
# NOTE: performing validation here to allow this class to be called directly avoiding http overhead
#
# inspired by http://www.thegreatcodeadventure.com/smarter-rails-services-with-active-record-modules/
class PreservedObjectHandler
  include ::MoabValidationHandler
  include ActiveModel::Validations

  validates :druid, presence: true, format: { with: DruidTools::Druid.pattern }
  validates :incoming_version, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :incoming_size, numericality: { only_integer: true, greater_than: 0 }
  validates_each :endpoint do |record, attr, value|
    unless value.is_a?(Endpoint)
      record.errors.add(attr, 'must be an actual Endpoint')
    end
  end

  attr_reader :druid, :incoming_version, :incoming_size, :endpoint, :results
  attr_writer :logger

  delegate :storage_location, to: :endpoint

  def initialize(druid, incoming_version, incoming_size, endpoint)
    @druid = druid
    @incoming_version = version_string_to_int(incoming_version)
    @incoming_size = string_to_int(incoming_size)
    @endpoint = endpoint
    @results = AuditResults.new(druid, incoming_version, endpoint)
    @logger = PreservationCatalog::Application.logger
  end

  def create_after_validation
    results.check_name = 'create_after_validation'
    if invalid?
      results.add_result(AuditResults::INVALID_ARGUMENTS, errors.full_messages)
    elsif PreservedObject.exists?(druid: druid)
      results.add_result(AuditResults::DB_OBJ_ALREADY_EXISTS, 'PreservedObject')
    elsif moab_validation_errors.empty?
      create_db_objects(PreservedCopy::VALIDITY_UNKNOWN_STATUS)
    else
      create_db_objects(PreservedCopy::INVALID_MOAB_STATUS)
    end

    results.report_results
  end

  def create
    results.check_name = 'create'
    if invalid?
      results.add_result(AuditResults::INVALID_ARGUMENTS, errors.full_messages)
    elsif PreservedObject.exists?(druid: druid)
      results.add_result(AuditResults::DB_OBJ_ALREADY_EXISTS, 'PreservedObject')
    else
      create_db_objects(PreservedCopy::VALIDITY_UNKNOWN_STATUS)
    end

    results.report_results
  end

  # this is a long, complex method (shameless green); if it is refactored, revisit the exceptions in rubocop.yml
  def check_existence
    results.check_name = 'check_existence'

    if invalid?
      results.add_result(AuditResults::INVALID_ARGUMENTS, errors.full_messages)
    elsif PreservedObject.exists?(druid: druid)
      Rails.logger.debug "check_existence #{druid} called"
      transaction_ok = with_active_record_transaction_and_rescue do
        raise_rollback_if_pc_po_version_mismatch

        return results.report_results unless can_validate_current_pres_copy_status?

        if incoming_version == pres_copy.version
          set_status_as_seen_on_disk(true) unless pres_copy.status == PreservedCopy::OK_STATUS
          results.add_result(AuditResults::VERSION_MATCHES, 'PreservedCopy')
        elsif incoming_version > pres_copy.version
          set_status_as_seen_on_disk(true) unless pres_copy.status == PreservedCopy::OK_STATUS
          results.add_result(AuditResults::ACTUAL_VERS_GT_DB_OBJ, db_obj_name: 'PreservedCopy', db_obj_version: pres_copy.version)
          if moab_validation_errors.empty?
            pres_copy.upd_audstamps_version_size(ran_moab_validation?, incoming_version, incoming_size)
            pres_object.current_version = incoming_version
            pres_object.save!
          else
            update_status(PreservedCopy::INVALID_MOAB_STATUS)
          end
        else # incoming_version < pres_copy.version
          set_status_as_seen_on_disk(false)
          results.add_result(AuditResults::ACTUAL_VERS_LT_DB_OBJ, db_obj_name: 'PreservedCopy', db_obj_version: pres_copy.version)
        end
        pres_copy.update_audit_timestamps(ran_moab_validation?, true)
        pres_copy.save!
      end
      results.remove_db_updated_results unless transaction_ok
    else
      results.add_result(AuditResults::DB_OBJ_DOES_NOT_EXIST, 'PreservedObject')
      if moab_validation_errors.empty?
        create_db_objects(PreservedCopy::VALIDITY_UNKNOWN_STATUS)
      else
        create_db_objects(PreservedCopy::INVALID_MOAB_STATUS)
      end
    end
    results.report_results
  end

  def confirm_version
    results.check_name = 'confirm_version'
    if invalid?
      results.add_result(AuditResults::INVALID_ARGUMENTS, errors.full_messages)
    else
      Rails.logger.debug "confirm_version #{druid} called"
      # NOTE: we deal with active record transactions in confirm_online_version, not here
      confirm_online_version
    end

    results.report_results
  end

  def update_version_after_validation
    results.check_name = 'update_version_after_validation'
    if invalid?
      results.add_result(AuditResults::INVALID_ARGUMENTS, errors.full_messages)
    else
      Rails.logger.debug "update_version_after_validation #{druid} called"
      if moab_validation_errors.empty?
        # NOTE: we deal with active record transactions in update_online_version, not here
        update_online_version(PreservedCopy::VALIDITY_UNKNOWN_STATUS)
      else
        update_pc_invalid_moab
      end
    end

    results.report_results
  end

  def update_version
    results.check_name = 'update_version'
    if invalid?
      results.add_result(AuditResults::INVALID_ARGUMENTS, errors.full_messages)
    else
      Rails.logger.debug "update_version #{druid} called"
      # NOTE: we deal with active record transactions in update_online_version, not here
      update_online_version(nil, true)
    end

    results.report_results
  end

  protected

  def pres_object
    @pres_object ||= PreservedObject.find_by!(druid: druid)
  end

  def pres_copy
    # FIXME: what if there is more than one associated pres_copy?
    @pres_copy ||= PreservedCopy.find_by!(preserved_object: pres_object, endpoint: endpoint)
  end

  alias preserved_copy pres_copy

  private

  def create_db_objects(status)
    pp_default_id = PreservationPolicy.default_policy.id
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

    results.add_result(AuditResults::CREATED_NEW_OBJECT) if transaction_ok
  end

  # TODO: this is "too complex" per rubocop: shameless green implementation
  # NOTE: if we can reduce complexity, remove Metrics/PerceivedComplexity exception in .rubocop.yml
  def update_online_version(status=nil, set_status_to_unexp_version=false)
    transaction_ok = with_active_record_transaction_and_rescue do
      raise_rollback_if_pc_po_version_mismatch

      # FIXME: what if there is more than one associated pres_copy?
      if incoming_version > pres_copy.version && pres_copy.matches_po_current_version?
        # add results without db updates
        code = AuditResults::ACTUAL_VERS_GT_DB_OBJ
        results.add_result(code, db_obj_name: 'PreservedCopy', db_obj_version: pres_copy.version)

        pres_copy.upd_audstamps_version_size(ran_moab_validation?, incoming_version, incoming_size)
        update_status(status) if status && ran_moab_validation?
        pres_copy.save!
        pres_object.current_version = incoming_version
        pres_object.save!
      else
        if set_status_to_unexp_version
          status = PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
        end
        update_pc_unexpected_version(status)
      end
    end

    results.remove_db_updated_results unless transaction_ok
  end

  def raise_rollback_if_pc_po_version_mismatch
    unless pres_copy.matches_po_current_version?
      pc_version = pres_copy.version
      po_version = pres_copy.preserved_object.current_version
      res_code = AuditResults::PC_PO_VERSION_MISMATCH
      results.add_result(res_code, { pc_version: pc_version, po_version: po_version })
      raise ActiveRecord::Rollback, "PreservedCopy version #{pc_version} != PreservedObject current_version #{po_version}"
    end
  end

  def update_pc_invalid_moab
    transaction_ok = with_active_record_transaction_and_rescue do
      update_status(PreservedCopy::INVALID_MOAB_STATUS)
      pres_copy.update_audit_timestamps(ran_moab_validation?, false)
      pres_copy.save!
    end
    results.remove_db_updated_results unless transaction_ok
  end

  def update_pc_unexpected_version(new_status)
    results.add_result(AuditResults::UNEXPECTED_VERSION, db_obj_name: 'PreservedCopy', db_obj_version: pres_copy.version)
    version_comparison_results

    update_status(new_status) if new_status
    pres_copy.update_audit_timestamps(ran_moab_validation?, true)
    pres_copy.save!
  end

  # shameless green implementation
  def confirm_online_version
    transaction_ok = with_active_record_transaction_and_rescue do
      raise_rollback_if_pc_po_version_mismatch

      return results.report_results unless can_validate_current_pres_copy_status?

      if incoming_version == pres_copy.version
        set_status_as_seen_on_disk(true) unless pres_copy.status == PreservedCopy::OK_STATUS
        results.add_result(AuditResults::VERSION_MATCHES, 'PreservedCopy')
      else
        set_status_as_seen_on_disk(false)
        results.add_result(AuditResults::UNEXPECTED_VERSION, db_obj_name: 'PreservedCopy', db_obj_version: pres_copy.version)
      end
      pres_copy.update_audit_timestamps(ran_moab_validation?, true)
      pres_copy.save!
    end
    results.remove_db_updated_results unless transaction_ok
  end

  # this wrapper reads a little nicer in this class, since POH is always doing this the same way
  def with_active_record_transaction_and_rescue
    ActiveRecordUtils.with_transaction_and_rescue(results) { yield }
  end

  # expects @incoming_version to be numeric
  def version_comparison_results
    if incoming_version == pres_copy.version
      results.add_result(AuditResults::VERSION_MATCHES, pres_copy.class.name)
    elsif incoming_version < pres_copy.version
      results.add_result(
        AuditResults::ACTUAL_VERS_LT_DB_OBJ,
        { db_obj_name: pres_copy.class.name, db_obj_version: pres_copy.version }
      )
    elsif incoming_version > pres_copy.version
      results.add_result(
        AuditResults::ACTUAL_VERS_GT_DB_OBJ,
        { db_obj_name: pres_copy.class.name, db_obj_version: pres_copy.version }
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
