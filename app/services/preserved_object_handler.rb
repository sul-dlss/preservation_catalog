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
  validates_each :moab_storage_root do |record, attr, value|
    unless value.is_a?(MoabStorageRoot)
      record.errors.add(attr, 'must be an actual MoabStorageRoot')
    end
  end

  attr_reader :druid, :incoming_version, :incoming_size, :moab_storage_root, :results
  attr_writer :logger

  delegate :storage_location, to: :moab_storage_root

  def initialize(druid, incoming_version, incoming_size, moab_storage_root)
    @druid = druid
    @incoming_version = version_string_to_int(incoming_version)
    @incoming_size = string_to_int(incoming_size)
    @moab_storage_root = moab_storage_root
    @results = AuditResults.new(druid, incoming_version, moab_storage_root)
    @logger = PreservationCatalog::Application.logger
  end

  # checksums_validated may be set to true if the caller takes responsibility for having validated the checksums
  def create_after_validation(checksums_validated = false)
    results.check_name = 'create_after_validation'
    if invalid?
      results.add_result(AuditResults::INVALID_ARGUMENTS, errors.full_messages)
    elsif PreservedObject.exists?(druid: druid)
      results.add_result(AuditResults::DB_OBJ_ALREADY_EXISTS, 'PreservedObject')
    elsif moab_validation_errors.empty?
      creation_status = (checksums_validated ? PreservedCopy::OK_STATUS : PreservedCopy::VALIDITY_UNKNOWN_STATUS)
      create_db_objects(creation_status, checksums_validated)
    else
      create_db_objects(PreservedCopy::INVALID_MOAB_STATUS, checksums_validated)
    end

    results.report_results
  end

  # checksums_validated may be set to true if the caller takes responsibility for having validated the checksums
  def create(checksums_validated = false)
    results.check_name = 'create'
    if invalid?
      results.add_result(AuditResults::INVALID_ARGUMENTS, errors.full_messages)
    elsif PreservedObject.exists?(druid: druid)
      results.add_result(AuditResults::DB_OBJ_ALREADY_EXISTS, 'PreservedObject')
    else
      creation_status = (checksums_validated ? PreservedCopy::OK_STATUS : PreservedCopy::VALIDITY_UNKNOWN_STATUS)
      ran_moab_validation! if checksums_validated # ensure validation timestamps updated
      create_db_objects(creation_status, checksums_validated)
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

  # checksums_validated may be set to true if the caller takes responsibility for having validated the checksums
  def update_version_after_validation(checksums_validated = false)
    results.check_name = 'update_version_after_validation'
    if invalid?
      results.add_result(AuditResults::INVALID_ARGUMENTS, errors.full_messages)
    elsif PreservedObject.exists?(druid: druid)
      Rails.logger.debug "update_version_after_validation #{druid} called"
      if moab_validation_errors.empty?
        # NOTE: we deal with active record transactions in update_online_version, not here
        new_status = (checksums_validated ? PreservedCopy::OK_STATUS : PreservedCopy::VALIDITY_UNKNOWN_STATUS)
        update_online_version(new_status, false, checksums_validated)
      else
        Rails.logger.debug "update_version_after_validation #{druid} found validation errors"
        if checksums_validated
          update_online_version(PreservedCopy::INVALID_MOAB_STATUS, false, true)
          # for case when no db updates b/c pres_obj version != pres_copy version
          update_pc_invalid_moab unless pres_copy.invalid_moab?
        else
          # TODO: we don't know checksum validity of incoming version, and we also have invalid moab
          #   so ideally we could report on moab validation errors (done) *and* queue up a checksum validity check
          update_online_version(PreservedCopy::VALIDITY_UNKNOWN_STATUS, false, false)
          # for case when no db updates b/c pres_obj version != pres_copy version
          update_pc_validity_unknown unless pres_copy.validity_unknown?
        end
      end
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

  # checksums_validated may be set to true if the caller takes responsibility for having validated the checksums
  def update_version(checksums_validated = false)
    results.check_name = 'update_version'
    if invalid?
      results.add_result(AuditResults::INVALID_ARGUMENTS, errors.full_messages)
    else
      Rails.logger.debug "update_version #{druid} called"
      # only change status if checksums_validated is false
      new_status = (checksums_validated ? nil : PreservedCopy::VALIDITY_UNKNOWN_STATUS)
      # NOTE: we deal with active record transactions in update_online_version, not here
      update_online_version(new_status, true, checksums_validated)
    end

    results.report_results
  end

  protected

  def pres_object
    @pres_object ||= PreservedObject.find_by!(druid: druid)
  end

  def pres_copy
    # FIXME: what if there is more than one associated pres_copy?
    @pres_copy ||= PreservedCopy.find_by!(preserved_object: pres_object, moab_storage_root: moab_storage_root)
  end

  alias preserved_copy pres_copy

  private

  def create_db_objects(status, checksums_validated = false)
    pp_default_id = PreservationPolicy.default_policy.id
    transaction_ok = with_active_record_transaction_and_rescue do
      po = PreservedObject.create!(druid: druid,
                                   current_version: incoming_version,
                                   preservation_policy_id: pp_default_id)
      pc_attrs = {
        preserved_object: po,
        version: incoming_version,
        size: incoming_size,
        moab_storage_root: moab_storage_root,
        status: status
      }
      t = Time.current
      if ran_moab_validation?
        pc_attrs[:last_version_audit] = t
        pc_attrs[:last_moab_validation] = t
      end
      pc_attrs[:last_checksum_validation] = t if checksums_validated
      PreservedCopy.create!(pc_attrs)
    end

    results.add_result(AuditResults::CREATED_NEW_OBJECT) if transaction_ok
  end

  # TODO: this is "too complex" per rubocop: shameless green implementation
  # NOTE: if we can reduce complexity, remove Metrics/PerceivedComplexity exception in .rubocop.yml
  def update_online_version(status=nil, set_status_to_unexp_version=false, checksums_validated=false)
    transaction_ok = with_active_record_transaction_and_rescue do
      raise_rollback_if_pc_po_version_mismatch

      # FIXME: what if there is more than one associated pres_copy?
      if incoming_version > pres_copy.version && pres_copy.matches_po_current_version?
        # add results without db updates
        code = AuditResults::ACTUAL_VERS_GT_DB_OBJ
        results.add_result(code, db_obj_name: 'PreservedCopy', db_obj_version: pres_copy.version)

        pres_copy.upd_audstamps_version_size(ran_moab_validation?, incoming_version, incoming_size)
        pres_copy.last_checksum_validation = Time.current if checksums_validated && pres_copy.last_checksum_validation
        update_status(status) if status
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

  def update_pc_validity_unknown
    transaction_ok = with_active_record_transaction_and_rescue do
      update_status(PreservedCopy::VALIDITY_UNKNOWN_STATUS)
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
