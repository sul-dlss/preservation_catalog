# creating a PreservedObject and/or updating check timestamps may require interactions
#  beyond the single PreservedObject model (e.g. PreservedCopy, PreservationPolicy).
#  This service class encapsulates logic to keep the controller and the model object
#    code simpler/thinner.
# NOTE: performing validation here to allow this class to be called directly avoiding http overhead
#
# inspired by http://www.thegreatcodeadventure.com/smarter-rails-services-with-active-record-modules/
class PreservedObjectHandler

  require 'preserved_object_handler_results.rb'

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
    @handler_results = PreservedObjectHandlerResults.new(druid, incoming_version, incoming_size, endpoint)
  end

  def create_after_validation
    if invalid?
      handler_results.add_result(PreservedObjectHandlerResults::INVALID_ARGUMENTS, errors.full_messages)
    elsif PreservedObject.exists?(druid: druid)
      handler_results.add_result(PreservedObjectHandlerResults::OBJECT_ALREADY_EXISTS, 'PreservedObject')
    elsif moab_validation_errors.empty?
      create_db_objects(PreservedCopy::OK_STATUS)
    else
      create_db_objects(PreservedCopy::INVALID_MOAB_STATUS)
    end

    handler_results.report_results
  end

  def create
    if invalid?
      handler_results.add_result(PreservedObjectHandlerResults::INVALID_ARGUMENTS, errors.full_messages)
    elsif PreservedObject.exists?(druid: druid)
      handler_results.add_result(PreservedObjectHandlerResults::OBJECT_ALREADY_EXISTS, 'PreservedObject')
    else
      create_db_objects(PreservedCopy::VALIDITY_UNKNOWN_STATUS)
    end

    handler_results.report_results
  end

  # this is a long, complex method (shameless green); if it is refactored, revisit the exceptions in rubocop.yml
  def check_existence
    if invalid?
      handler_results.add_result(PreservedObjectHandlerResults::INVALID_ARGUMENTS, errors.full_messages)
    elsif PreservedObject.exists?(druid: druid)
      Rails.logger.debug "check_existence #{druid} called"
      if endpoint.endpoint_type.endpoint_class == 'online'
        transaction_ok = with_active_record_transaction_and_rescue do
          pres_object = PreservedObject.find_by!(druid: druid)
          # FIXME: what if there is more than one associated pres_copy?
          pres_copy = PreservedCopy.find_by!(preserved_object: pres_object, endpoint: endpoint) if pres_object

          raise_rollback_if_pc_po_version_mismatch(pres_copy.version, pres_object.current_version)

          if incoming_version == pres_copy.version
            check_status_if_not_ok_or_unexpected_version(pres_copy, true)
            handler_results.add_result(PreservedObjectHandlerResults::VERSION_MATCHES, pres_copy.class.name)
            handler_results.add_result(PreservedObjectHandlerResults::VERSION_MATCHES, pres_object.class.name)
          elsif incoming_version > pres_copy.version
            check_status_if_not_ok_or_unexpected_version(pres_copy, true)
            handler_results.add_result(PreservedObjectHandlerResults::ARG_VERSION_GREATER_THAN_DB_OBJECT, pres_copy.class.name)
            handler_results.add_result(PreservedObjectHandlerResults::ARG_VERSION_GREATER_THAN_DB_OBJECT, pres_object.class.name)
            if moab_validation_errors.empty?
              update_preserved_copy_version_etc(pres_copy, incoming_version, incoming_size)
              pres_object.current_version = incoming_version
              update_db_object(pres_object)
            else
              update_status(pres_copy, PreservedCopy::INVALID_MOAB_STATUS)
            end
          else # incoming_version < pres_copy.version
            check_status_if_not_ok_or_unexpected_version(pres_copy, false)
            handler_results.add_result(PreservedObjectHandlerResults::ARG_VERSION_LESS_THAN_DB_OBJECT, pres_copy.class.name)
            handler_results.add_result(PreservedObjectHandlerResults::ARG_VERSION_LESS_THAN_DB_OBJECT, pres_object.class.name)
          end
          update_pc_audit_timestamps(pres_copy, true)
          update_db_object(pres_copy)
        end
        handler_results.remove_db_updated_results unless transaction_ok
      elsif endpoint.endpoint_type.endpoint_class == 'archive'
        # TODO: note that an endpoint PC version might not match PO.current_version
      end
    else
      handler_results.add_result(PreservedObjectHandlerResults::OBJECT_DOES_NOT_EXIST, 'PreservedObject')
      if moab_validation_errors.empty?
        create_db_objects(PreservedCopy::OK_STATUS)
      else
        create_db_objects(PreservedCopy::INVALID_MOAB_STATUS)
      end
    end
    handler_results.report_results
  end

  def confirm_version
    if invalid?
      handler_results.add_result(PreservedObjectHandlerResults::INVALID_ARGUMENTS, errors.full_messages)
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
    if invalid?
      handler_results.add_result(PreservedObjectHandlerResults::INVALID_ARGUMENTS, errors.full_messages)
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
    if invalid?
      handler_results.add_result(PreservedObjectHandlerResults::INVALID_ARGUMENTS, errors.full_messages)
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
          handler_results.add_result(PreservedObjectHandlerResults::INVALID_MOAB, moab_error_msgs)
        end
        moab_errors
      end
  end

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

    handler_results.add_result(PreservedObjectHandlerResults::CREATED_NEW_OBJECT) if transaction_ok
  end

  # TODO: this is "too complex" per rubocop: shameless green implementation
  # NOTE: if we can reduce complexity, remove Metrics/PerceivedComplexity exception in .rubocop.yml
  def update_online_version(status=nil, set_status_to_unexp_version=false)
    transaction_ok = with_active_record_transaction_and_rescue do
      pres_object = PreservedObject.find_by!(druid: druid)
      pres_copy = PreservedCopy.find_by!(preserved_object: pres_object, endpoint: endpoint) if pres_object

      raise_rollback_if_pc_po_version_mismatch(pres_copy.version, pres_object.current_version)

      # FIXME: what if there is more than one associated pres_copy?
      if incoming_version > pres_copy.version && pres_copy.version == pres_object.current_version
        # add results without db updates
        code = PreservedObjectHandlerResults::ARG_VERSION_GREATER_THAN_DB_OBJECT
        handler_results.add_result(code, pres_copy.class.name)
        handler_results.add_result(code, pres_object.class.name)

        update_preserved_copy_version_etc(pres_copy, incoming_version, incoming_size)
        update_status(pres_copy, status) if status && ran_moab_validation?
        update_db_object(pres_copy)
        pres_object.current_version = incoming_version
        update_db_object(pres_object)
      else
        if set_status_to_unexp_version
          status = PreservedCopy::EXPECTED_VERS_NOT_FOUND_ON_STORAGE_STATUS
        end
        update_pc_unexpected_version(pres_copy, pres_object, status)
      end
    end

    handler_results.remove_db_updated_results unless transaction_ok
  end

  def raise_rollback_if_pc_po_version_mismatch(pc_version, po_version)
    if pc_version != po_version
      res_code = PreservedObjectHandlerResults::PC_PO_VERSION_MISMATCH
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
      update_pc_audit_timestamps(pres_copy, false)
      update_db_object(pres_copy)
    end
    handler_results.remove_db_updated_results unless transaction_ok
  end

  def check_status_if_not_ok_or_unexpected_version(pres_copy, found_expected_version)
    unless pres_copy.status == PreservedCopy::OK_STATUS && found_expected_version
      set_status_as_seen_on_disk(pres_copy, found_expected_version)
    end
  end

  # given a PreservedCopy instance and whether the caller found the expected version of it on disk, this will perform
  # other validations of what's on disk, and will update the status accordingly
  def set_status_as_seen_on_disk(pres_copy, found_expected_version)
    # TODO: when we implement C2M, we should add a check here to look for the object on disk, and set PreservedCopy::ONLINE_MOAB_NOT_FOUND_STATUS
    # if needed.  or maybe the caller will have done that already, since it needs to try reading the moab to obtain incoming_version?

    unless moab_validation_errors.empty?
      update_status(pres_copy, PreservedCopy::INVALID_MOAB_STATUS)
      return
    end

    unless found_expected_version
      update_status(pres_copy, PreservedCopy::EXPECTED_VERS_NOT_FOUND_ON_STORAGE_STATUS)
      return
    end

    # TODO: do the check that'd set INVALID_CHECKSUM_STATUS

    # TODO: do the check that'd set FIXITY_CHECK_FAILED_STATUS

    update_status(pres_copy, PreservedCopy::OK_STATUS)
  end

  def update_pc_unexpected_version(pres_copy, pres_object, new_status)
    handler_results.add_result(PreservedObjectHandlerResults::UNEXPECTED_VERSION, 'PreservedCopy')
    version_comparison_results(pres_copy, :version)
    version_comparison_results(pres_object, :current_version)

    update_status(pres_copy, new_status) if new_status
    update_pc_audit_timestamps(pres_copy, true)
    update_db_object(pres_copy)
  end

  # shameless green implementation
  def confirm_online_version
    transaction_ok = with_active_record_transaction_and_rescue do
      pres_object = PreservedObject.find_by!(druid: druid)
      # FIXME: what if there is more than one associated pres_copy?
      pres_copy = PreservedCopy.find_by!(preserved_object: pres_object, endpoint: endpoint) if pres_object

      raise_rollback_if_pc_po_version_mismatch(pres_copy.version, pres_object.current_version)

      if incoming_version == pres_copy.version
        check_status_if_not_ok_or_unexpected_version(pres_copy, true)
        handler_results.add_result(PreservedObjectHandlerResults::VERSION_MATCHES, pres_copy.class.name)
        handler_results.add_result(PreservedObjectHandlerResults::VERSION_MATCHES, pres_object.class.name)
      else
        check_status_if_not_ok_or_unexpected_version(pres_copy, false)
        handler_results.add_result(PreservedObjectHandlerResults::UNEXPECTED_VERSION, pres_copy.class.name)
      end
      update_pc_audit_timestamps(pres_copy, true)
      update_db_object(pres_copy)
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
      handler_results.add_result(PreservedObjectHandlerResults::OBJECT_DOES_NOT_EXIST, e.inspect)
    rescue ActiveRecord::ActiveRecordError => e
      handler_results.add_result(
        PreservedObjectHandlerResults::DB_UPDATE_FAILED, "#{e.inspect} #{e.message} #{e.backtrace.inspect}"
      )
    end
    false
  end

  # expects @incoming_version to be numeric
  def update_preserved_copy_version_etc(pres_copy, new_version, new_size)
    pres_copy.version = new_version
    pres_copy.size = new_size if new_size
    update_pc_audit_timestamps(pres_copy, true)
  end

  def update_pc_audit_timestamps(pres_copy, version_audited)
    t = Time.current
    pres_copy.last_moab_validation = t if ran_moab_validation?
    pres_copy.last_version_audit = t if version_audited
  end

  # expects @incoming_version to be numeric
  def version_comparison_results(db_object, version_symbol)
    if incoming_version == db_object.send(version_symbol)
      handler_results.add_result(PreservedObjectHandlerResults::VERSION_MATCHES, db_object.class.name)
    elsif incoming_version < db_object.send(version_symbol)
      handler_results.add_result(PreservedObjectHandlerResults::ARG_VERSION_LESS_THAN_DB_OBJECT, db_object.class.name)
    elsif incoming_version > db_object.send(version_symbol)
      handler_results.add_result(PreservedObjectHandlerResults::ARG_VERSION_GREATER_THAN_DB_OBJECT, db_object.class.name)
    end
  end

  def update_status(preserved_copy, new_status)
    if new_status != preserved_copy.status
      handler_results.add_result(
        PreservedObjectHandlerResults::PC_STATUS_CHANGED,
        { old_status: preserved_copy.status, new_status: new_status }
      )
      preserved_copy.status = new_status
    end
  end

  # TODO: this may need reworking if we need to distinguish db timestamp updates when
  #   version matched vs. incoming version less than db object
  def update_db_object(db_object)
    if db_object.changed?
      db_object.save!
      handler_results.add_result(PreservedObjectHandlerResults::UPDATED_DB_OBJECT, db_object.class.name)
    else
      # FIXME: we may not want to do this, but instead to update specific timestamp for check
      db_object.touch
      handler_results.add_result(PreservedObjectHandlerResults::UPDATED_DB_OBJECT_TIMESTAMP_ONLY, db_object.class.name)
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
