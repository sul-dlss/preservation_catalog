# frozen_string_literal: true

# creating a CompleteMoab and/or updating check timestamps may require interactions
#  beyond the single CompleteMoab model (e.g. PreservedObject, PreservationPolicy).
#  This service class encapsulates logic to keep the controller and the model object
#    code simpler/thinner.
# NOTE: performing validation here to allow this class to be called directly avoiding http overhead
#
# inspired by http://www.thegreatcodeadventure.com/smarter-rails-services-with-active-record-modules/
class CompleteMoabHandler
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
  delegate :can_validate_current_comp_moab_status?,
           :complete_moab,
           :moab_validation_errors,
           :ran_moab_validation?,
           :ran_moab_validation!,
           :set_status_as_seen_on_disk,
           :update_status,
           to: :moab_validator

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
    elsif CompleteMoab.by_druid(druid).by_storage_root(moab_storage_root).exists?
      results.add_result(AuditResults::DB_OBJ_ALREADY_EXISTS, 'CompleteMoab')
    elsif moab_validation_errors.empty?
      creation_status = (checksums_validated ? 'ok' : 'validity_unknown')
      create_db_objects(creation_status, checksums_validated)
    else
      create_db_objects('invalid_moab', checksums_validated)
    end

    results.report_results
  end

  # checksums_validated may be set to true if the caller takes responsibility for having validated the checksums
  def create(checksums_validated = false)
    results.check_name = 'create'
    if invalid?
      results.add_result(AuditResults::INVALID_ARGUMENTS, errors.full_messages)
    elsif CompleteMoab.by_druid(druid).by_storage_root(moab_storage_root).exists?
      results.add_result(AuditResults::DB_OBJ_ALREADY_EXISTS, 'CompleteMoab')
    else
      creation_status = (checksums_validated ? 'ok' : 'validity_unknown')
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
    elsif CompleteMoab.by_druid(druid).by_storage_root(moab_storage_root).exists?
      Rails.logger.debug "check_existence #{druid} called"

      transaction_ok = with_active_record_transaction_and_rescue do
        raise_rollback_if_cm_po_version_mismatch

        return results.report_results unless can_validate_current_comp_moab_status?

        if incoming_version == complete_moab.version
          set_status_as_seen_on_disk(true) unless complete_moab.status == 'ok'
          results.add_result(AuditResults::VERSION_MATCHES, 'CompleteMoab')
        elsif incoming_version > complete_moab.version
          set_status_as_seen_on_disk(true) unless complete_moab.status == 'ok'
          results.add_result(AuditResults::ACTUAL_VERS_GT_DB_OBJ, db_obj_name: 'CompleteMoab', db_obj_version: complete_moab.version)
          update_cm_po_set_status
        else # incoming_version < complete_moab.version
          set_status_as_seen_on_disk(false)
          results.add_result(AuditResults::ACTUAL_VERS_LT_DB_OBJ, db_obj_name: 'CompleteMoab', db_obj_version: complete_moab.version)
        end
        complete_moab.update_audit_timestamps(ran_moab_validation?, true)
        complete_moab.save!
      end
      results.remove_db_updated_results unless transaction_ok
    else
      results.add_result(AuditResults::DB_OBJ_DOES_NOT_EXIST, 'CompleteMoab')
      if moab_validation_errors.empty?
        create_db_objects('validity_unknown')
      else
        create_db_objects('invalid_moab')
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
    elsif CompleteMoab.by_druid(druid).by_storage_root(moab_storage_root).exists?
      Rails.logger.debug "update_version_after_validation #{druid} called"
      if moab_validation_errors.empty?
        # NOTE: we deal with active record transactions in update_online_version, not here
        new_status = (checksums_validated ? 'ok' : 'validity_unknown')
        update_online_version(new_status, false, checksums_validated)
      else
        Rails.logger.debug "update_version_after_validation #{druid} found validation errors"
        if checksums_validated
          update_online_version('invalid_moab', false, true)
          # for case when no db updates b/c pres_obj version != complete_moab version
          update_cm_invalid_moab unless complete_moab.invalid_moab?
        else
          update_online_version('validity_unknown', false, false)
          # for case when no db updates b/c pres_obj version != complete_moab version
          update_cm_validity_unknown unless complete_moab.validity_unknown?
        end
      end
    else
      results.add_result(AuditResults::DB_OBJ_DOES_NOT_EXIST, 'CompleteMoab')
      if moab_validation_errors.empty?
        create_db_objects('validity_unknown')
      else
        create_db_objects('invalid_moab')
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
      new_status = (checksums_validated ? nil : 'validity_unknown')
      # NOTE: we deal with active record transactions in update_online_version, not here
      update_online_version(new_status, true, checksums_validated)
    end

    results.report_results
  end

  def pres_object
    @pres_object ||= PreservedObject.find_by!(druid: druid)
  end

  private

  def moab_validator
    @moab_validator ||= MoabValidator.new(druid: druid, storage_location: storage_location, results: results)
  end

  # Note that this may be called by running M2C on a storage root and discovering a second copy of a Moab,
  #   or maybe by calling #create_after_validation directly after copying a Moab
  def create_db_objects(status, checksums_validated = false)
    cm_attrs = {
      version: incoming_version,
      size: incoming_size,
      moab_storage_root: moab_storage_root,
      status: status
    }
    t = Time.current
    if ran_moab_validation?
      cm_attrs[:last_version_audit] = t
      cm_attrs[:last_moab_validation] = t
    end
    cm_attrs[:last_checksum_validation] = t if checksums_validated
    ppid = PreservationPolicy.default_policy.id

    # TODO: remove tests' dependence on 2 "create!" calls, use single built-in AR transactionality
    transaction_ok = with_active_record_transaction_and_rescue do
      this_po = PreservedObject
                .find_or_create_by!(druid: druid) do |po|
                  po.current_version = incoming_version
                  po.preservation_policy_id = ppid
                end
      this_cm = this_po.complete_moabs.create!(cm_attrs)
      # add to join table unless there is already a primary moab
      PreservedObjectsPrimaryMoab.find_or_create_by!(preserved_object: this_po, complete_moab: this_cm)
    end
    results.add_result(AuditResults::CREATED_NEW_OBJECT) if transaction_ok
  end

  # TODO: this is "too complex" per rubocop: shameless green implementation
  # NOTE: if we can reduce complexity, remove Metrics/PerceivedComplexity exception in .rubocop.yml
  def update_online_version(status = nil, set_status_to_unexp_version = false, checksums_validated = false)
    transaction_ok = with_active_record_transaction_and_rescue do
      raise_rollback_if_cm_po_version_mismatch

      # FIXME: what if there is more than one associated complete_moab?
      if incoming_version > complete_moab.version && complete_moab.matches_po_current_version?
        # add results without db updates
        code = AuditResults::ACTUAL_VERS_GT_DB_OBJ
        results.add_result(code, db_obj_name: 'CompleteMoab', db_obj_version: complete_moab.version)

        complete_moab.upd_audstamps_version_size(ran_moab_validation?, incoming_version, incoming_size)
        complete_moab.last_checksum_validation = Time.current if checksums_validated && complete_moab.last_checksum_validation
        update_status(status) if status
        complete_moab.save!
        pres_object.current_version = incoming_version
        pres_object.save!
      else
        status = 'unexpected_version_on_storage' if set_status_to_unexp_version
        update_cm_unexpected_version(status)
      end
    end

    results.remove_db_updated_results unless transaction_ok
  end

  def update_cm_po_set_status
    if moab_validation_errors.empty?
      complete_moab.upd_audstamps_version_size(ran_moab_validation?, incoming_version, incoming_size)
      pres_object.current_version = incoming_version
      pres_object.save!
    else
      update_status('invalid_moab')
    end
  end

  def raise_rollback_if_cm_po_version_mismatch
    unless complete_moab.matches_po_current_version?
      cm_version = complete_moab.version
      po_version = complete_moab.preserved_object.current_version
      res_code = AuditResults::CM_PO_VERSION_MISMATCH
      results.add_result(res_code, cm_version: cm_version, po_version: po_version)
      raise ActiveRecord::Rollback, "CompleteMoab version #{cm_version} != PreservedObject current_version #{po_version}"
    end
  end

  def update_cm_invalid_moab
    transaction_ok = with_active_record_transaction_and_rescue do
      update_status('invalid_moab')
      complete_moab.update_audit_timestamps(ran_moab_validation?, false)
      complete_moab.save!
    end
    results.remove_db_updated_results unless transaction_ok
  end

  def update_cm_validity_unknown
    transaction_ok = with_active_record_transaction_and_rescue do
      update_status('validity_unknown')
      complete_moab.update_audit_timestamps(ran_moab_validation?, false)
      complete_moab.save!
    end
    results.remove_db_updated_results unless transaction_ok
  end

  def update_cm_unexpected_version(new_status)
    results.add_result(AuditResults::UNEXPECTED_VERSION, db_obj_name: 'CompleteMoab', db_obj_version: complete_moab.version)
    version_comparison_results

    update_status(new_status) if new_status
    complete_moab.update_audit_timestamps(ran_moab_validation?, true)
    complete_moab.save!
  end

  # shameless green implementation
  def confirm_online_version
    transaction_ok = with_active_record_transaction_and_rescue do
      raise_rollback_if_cm_po_version_mismatch

      return results.report_results unless can_validate_current_comp_moab_status?

      if incoming_version == complete_moab.version
        set_status_as_seen_on_disk(true) unless complete_moab.status == 'ok'
        results.add_result(AuditResults::VERSION_MATCHES, 'CompleteMoab')
      else
        set_status_as_seen_on_disk(false)
        results.add_result(AuditResults::UNEXPECTED_VERSION, db_obj_name: 'CompleteMoab', db_obj_version: complete_moab.version)
      end
      complete_moab.update_audit_timestamps(ran_moab_validation?, true)
      complete_moab.save!
    end
    results.remove_db_updated_results unless transaction_ok
  end

  # this wrapper reads a little nicer in this class, since CompleteMoabHandler is always doing this the same way
  def with_active_record_transaction_and_rescue
    ActiveRecordUtils.with_transaction_and_rescue(results) { yield }
  end

  # expects @incoming_version to be numeric
  def version_comparison_results
    if incoming_version == complete_moab.version
      results.add_result(AuditResults::VERSION_MATCHES, complete_moab.class.name)
    elsif incoming_version < complete_moab.version
      results.add_result(
        AuditResults::ACTUAL_VERS_LT_DB_OBJ,
        db_obj_name: complete_moab.class.name, db_obj_version: complete_moab.version
      )
    elsif incoming_version > complete_moab.version
      results.add_result(
        AuditResults::ACTUAL_VERS_GT_DB_OBJ,
        db_obj_name: complete_moab.class.name, db_obj_version: complete_moab.version
      )
    end
  end

  def version_string_to_int(val)
    result = string_to_int(val)
    return result if result.instance_of?(Integer)
    # accommodate 'vnnn' strings from Moab version directories
    return val[1..].to_i if val.instance_of?(String) && val.match(/^v\d+$/)
    val
  end

  def string_to_int(val)
    return if val.blank?
    return val if val.instance_of?(Integer) # NOTE: negative integers caught with validation
    return val.to_i if val.instance_of?(String) && val.scan(/\D/).empty?
    val
  end
end
