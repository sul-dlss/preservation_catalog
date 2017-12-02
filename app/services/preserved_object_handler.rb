# creating a PreservedObject and/or updating check timestamps may require interactions
#  beyond the single PreservedObject model (e.g. PreservedCopy, PreservationPolicy).
#  This service class encapsulates logic to keep the controller and the model object
#    code simpler/thinner.
# NOTE: performing validation here to allow this class to be called directly avoiding http overhead
#
# inspired by http://www.thegreatcodeadventure.com/smarter-rails-services-with-active-record-modules/
class PreservedObjectHandler

  INVALID_ARGUMENTS = 1
  VERSION_MATCHES = 2
  ARG_VERSION_GREATER_THAN_DB_OBJECT = 3
  ARG_VERSION_LESS_THAN_DB_OBJECT = 4
  UPDATED_DB_OBJECT = 5
  UPDATED_DB_OBJECT_TIMESTAMP_ONLY = 6
  CREATED_NEW_OBJECT = 7
  DB_UPDATE_FAILED = 8
  OBJECT_ALREADY_EXISTS = 9
  OBJECT_DOES_NOT_EXIST = 10
  PC_STATUS_CHANGED = 11
  UNEXPECTED_VERSION = 12
  INVALID_MOAB = 13

  RESPONSE_CODE_TO_MESSAGES = {
    INVALID_ARGUMENTS => "encountered validation error(s): %{addl}",
    VERSION_MATCHES => "incoming version (%{incoming_version}) matches %{addl} db version",
    ARG_VERSION_GREATER_THAN_DB_OBJECT => "incoming version (%{incoming_version}) greater than %{addl} db version",
    ARG_VERSION_LESS_THAN_DB_OBJECT => "incoming version (%{incoming_version}) less than %{addl} db version; ERROR!",
    UPDATED_DB_OBJECT => "%{addl} db object updated",
    UPDATED_DB_OBJECT_TIMESTAMP_ONLY => "%{addl} updated db timestamp only",
    CREATED_NEW_OBJECT => "added object to db as it did not exist",
    DB_UPDATE_FAILED => "db update failed: %{addl}",
    OBJECT_ALREADY_EXISTS => "%{addl} db object already exists",
    OBJECT_DOES_NOT_EXIST => "%{addl} db object does not exist",
    PC_STATUS_CHANGED => "PreservedCopy status changed from %{old_status} to %{new_status}",
    UNEXPECTED_VERSION => "incoming version (%{incoming_version}) has unexpected relationship to %{addl} db version; ERROR!",
    INVALID_MOAB => "Invalid moab, validation errors: %{addl}"
  }.freeze

  include ActiveModel::Validations

  # Note: supplying validations here to allow validation before use, e.g. incoming_version in numeric logic
  validates :druid, presence: true, format: { with: DruidTools::Druid.pattern }
  validates :incoming_version, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :incoming_size, numericality: { only_integer: true, greater_than: 0 }
  validates_each :endpoint do |record, attr, value|
    record.errors.add(attr, 'must be an actual Endpoint') unless value.is_a?(Endpoint)
  end

  attr_reader :druid, :incoming_version, :incoming_size, :endpoint

  delegate :storage_location, to: :endpoint

  def initialize(druid, incoming_version, incoming_size, endpoint)
    @druid = druid
    @incoming_version = version_string_to_int(incoming_version)
    @incoming_size = string_to_int(incoming_size)
    @endpoint = endpoint
  end

  def create_after_validation
    results = []
    if invalid?
      results << result_hash(INVALID_ARGUMENTS, errors.full_messages)
    elsif PreservedObject.exists?(druid: druid)
      results << result_hash(OBJECT_ALREADY_EXISTS, 'PreservedObject')
    elsif moab_validation_errors.empty?
      results.concat(create_db_objects(Status.default_status, true))
    else
      results.concat(create_db_objects(Status.invalid_moab, true))
    end

    log_results(results)
    results
  end

  def create
    results = []
    if invalid?
      results << result_hash(INVALID_ARGUMENTS, errors.full_messages)
    elsif PreservedObject.exists?(druid: druid)
      results << result_hash(OBJECT_ALREADY_EXISTS, 'PreservedObject')
    else
      results.concat(create_db_objects(Status.default_status))
    end

    log_results(results)
    results
  end

  def confirm_version
    results = []
    if invalid?
      results << result_hash(INVALID_ARGUMENTS, errors.full_messages)
    else
      Rails.logger.debug "confirm_version #{druid} called"
      results.concat(confirm_version_in_catalog)
    end

    log_results(results)
    results
  end

  def update_version_after_validation
    results = []
    if invalid?
      results << result_hash(INVALID_ARGUMENTS, errors.full_messages)
    else
      Rails.logger.debug "update_version_after_validation #{druid} called"
      if endpoint.endpoint_type.endpoint_class == 'online'
        # NOTE: we deal with active record transactions in update_online_version, not here
        if moab_validation_errors.empty?
          results.concat update_online_version(true, Status.ok)
        else
          results.concat update_online_version(true, Status.invalid_moab)
        end
      elsif endpoint.endpoint_type.endpoint_class == 'archive'
        # TODO: perform archive object validation; then create a new PC record for the new
        #  archived version on the endpoint
      end
    end

    log_results(results)
    results
  end

  def update_version
    results = []
    if invalid?
      results << result_hash(INVALID_ARGUMENTS, errors.full_messages)
    else
      Rails.logger.debug "update_version #{druid} called"
      if endpoint.endpoint_type.endpoint_class == 'online'
        # NOTE: we deal with active record transactions in update_online_version, not here
        results.concat update_online_version
      elsif endpoint.endpoint_type.endpoint_class == 'archive'
        # TODO: create a new PC record for the new archived version on the endpoint
      end
    end

    log_results(results)
    results
  end

  private

  def moab_validation_errors
    results = []
    object_dir = "#{storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}"
    moab = Moab::StorageObject.new(druid, object_dir)
    object_validator = Stanford::StorageObjectValidator.new(moab)
    errors = object_validator.validation_errors(Settings.moab.allow_content_subdirs)
    if errors.any?
      moab_error_msg_list = []
      errors.each do |error_hash|
        error_hash.each_value { |moab_error_msgs| moab_error_msg_list << moab_error_msgs }
      end
      results << result_hash(INVALID_MOAB, moab_error_msg_list)
      log_results(results)
    end
    errors
  end

  def create_db_objects(status, validated=false)
    results = []
    pp_default = PreservationPolicy.default_preservation_policy
    transaction_results = with_active_record_transaction_and_rescue do
      po = PreservedObject.create!(druid: druid,
                                   current_version: incoming_version,
                                   preservation_policy: pp_default)
      pc_attrs = {
        preserved_object: po,
        version: incoming_version,
        size: incoming_size,
        endpoint: endpoint,
        status: status
      }

      if validated
        t = Time.current
        # Returns the value of time as an integer number of seconds since the Epoch.
        pc_attrs[:last_audited] = t.to_i
        pc_attrs[:last_checked_on_storage] = t
      end
      PreservedCopy.create!(pc_attrs)
    end

    if transaction_results.empty?
      results << result_hash(CREATED_NEW_OBJECT)
    else
      results.concat(transaction_results)
    end
  end

  # TODO: this is "too complex" per rubocop: shameless green implementation
  # NOTE: if reduce complexity, remove Metrics/PerceivedComplexity exception in .rubocop.yml
  def update_online_version(validated=false, status=nil)
    full_results = []

    # don't concat the db update results as we go, since one upd in the series may
    # fail, causing a rollback and making those results untrue.  instead, concat those
    # results to the final list once we know the transaction has successfully committed.
    db_upd_results = []

    transaction_results = with_active_record_transaction_and_rescue do
      pres_object = PreservedObject.find_by!(druid: druid)
      pres_copy = PreservedCopy.find_by!(preserved_object: pres_object, endpoint: endpoint) if pres_object
      # FIXME: what if there is more than one associated pres_copy?
      if incoming_version > pres_copy.version && pres_copy.version == pres_object.current_version
        # fine to append this result, because it's true regardless of whether the transaction succeeds
        full_results << result_hash(ARG_VERSION_GREATER_THAN_DB_OBJECT, pres_copy.class.name)
        update_preserved_copy_version_etc(pres_copy, incoming_version, incoming_size, validated)
        db_upd_results.concat(update_status(pres_copy, status)) if status
        db_upd_results.concat(update_db_object(pres_copy))
        # fine to append this result, because it's true regardless of whether the transaction succeeds
        full_results << result_hash(ARG_VERSION_GREATER_THAN_DB_OBJECT, pres_object.class.name)
        pres_object.current_version = incoming_version
        db_upd_results.concat(update_db_object(pres_object))
      else
        # these just add result codes about object state w/o touching DB, so can append immediately to rull result list
        full_results << result_hash(UNEXPECTED_VERSION, 'PreservedCopy')
        full_results.concat(version_comparison_results(pres_copy, :version))
        full_results.concat(version_comparison_results(pres_object, :current_version))

        # update_status and update_db_object both touch the db, so same circumspect handling of results from them
        db_upd_results.concat(update_status(pres_copy, status)) if status
        update_pc_validation_timestamps(pres_copy) if validated
        db_upd_results.concat(update_db_object(pres_copy)) if pres_copy.changed?
      end
    end

    # ok, now we're out of the woods:  if we're here, the transaction is over.  and if it produced no results
    # of its own, it completed and committed successfully.  so if there were no error codes produced from the
    # transaction running and committing, return the update results, otherwise, return the transaction failure code(s).
    if transaction_results.empty?
      full_results.concat(db_upd_results)
    else
      full_results.concat(transaction_results)
    end
  end

  def confirm_version_in_catalog
    results = []
    confirm_results = with_active_record_transaction_and_rescue do
      po_db_object = PreservedObject.find_by!(druid: druid)
      pc_db_object = PreservedCopy.find_by!(preserved_object: po_db_object, endpoint: endpoint)
      results.concat(confirm_version_on_db_object(po_db_object, :current_version))
      results.concat(confirm_version_on_db_object(pc_db_object, :version))
    end
    results.concat(confirm_results)
  end

  def with_active_record_transaction_and_rescue
    results = []
    begin
      ApplicationRecord.transaction { yield }
    rescue ActiveRecord::RecordNotFound => e
      results << result_hash(OBJECT_DOES_NOT_EXIST, e.inspect)
    rescue ActiveRecord::ActiveRecordError => e
      results << result_hash(DB_UPDATE_FAILED, "#{e.inspect} #{e.message} #{e.backtrace.inspect}")
    end
    results
  end

  # expects @incoming_version to be numeric
  def update_preserved_copy_version_etc(pres_copy, new_version, new_size, validated=false)
    pres_copy.version = new_version
    pres_copy.size = new_size if new_size
    update_pc_validation_timestamps(pres_copy) if validated
  end

  def update_pc_validation_timestamps(pres_copy)
    t = Time.current
    pres_copy.last_audited = t.to_i
    pres_copy.last_checked_on_storage = t
  end

  # expects @incoming_version to be numeric
  def version_comparison_results(db_object, version_symbol)
    results = []
    if incoming_version == db_object.send(version_symbol)
      results << result_hash(VERSION_MATCHES, db_object.class.name)
    elsif incoming_version < db_object.send(version_symbol)
      results << result_hash(ARG_VERSION_LESS_THAN_DB_OBJECT, db_object.class.name)
    elsif incoming_version > db_object.send(version_symbol)
      results << result_hash(ARG_VERSION_GREATER_THAN_DB_OBJECT, db_object.class.name)
    end
    results
  end

  # FIXME: this needs to go away in favor of ? update_version_after_validation
  #  it is only used by confirm_version, which should essentially call
  #  update_version_after_validation if the incoming_version is higher than the db
  # One big problem with this is the overwriting of the PC status without validating first
  def increase_version(db_object)
    results = []
    results << result_hash(ARG_VERSION_GREATER_THAN_DB_OBJECT, db_object.class.name)
    if db_object.is_a?(PreservedCopy)
      update_preserved_copy_version_etc(db_object, incoming_version, incoming_size)
      results.concat(update_status(db_object, Status.ok))
    elsif db_object.is_a?(PreservedObject)
      db_object.current_version = incoming_version
    end
    results
  end

  # expects @incoming_version to be numeric
  # TODO: revisit naming
  def confirm_version_on_db_object(db_object, version_symbol)
    results = []
    if incoming_version == db_object.send(version_symbol)
      results.concat(update_status(db_object, Status.ok)) if db_object.is_a?(PreservedCopy)
      results << result_hash(VERSION_MATCHES, db_object.class.name)
    elsif incoming_version > db_object.send(version_symbol)
      # FIXME: this needs to use the same methods as update_version_after_validation
      results.concat(increase_version(db_object))
    else
      # TODO: needs manual intervention until automatic recovery services implemented
      results.concat(update_status(db_object, Status.unexpected_version)) if db_object.is_a?(PreservedCopy)
      results << result_hash(ARG_VERSION_LESS_THAN_DB_OBJECT, db_object.class.name)
    end
    results.concat(update_db_object(db_object))
    results
  end

  def update_status(preserved_copy, new_status)
    results = []
    if new_status != preserved_copy.status
      results << result_hash(
        PC_STATUS_CHANGED,
        { old_status: preserved_copy.status.status_text, new_status: new_status.status_text }
      )
      preserved_copy.status = new_status
    end
    results
  end

  # TODO: this may need reworking if we need to distinguish db timestamp updates when
  #   version matched vs. incoming version less than db object
  def update_db_object(db_object)
    results = []
    if db_object.changed?
      db_object.save!
      results << result_hash(UPDATED_DB_OBJECT, db_object.class.name)
    else
      # FIXME: we may not want to do this, but instead to update specific timestamp for check
      db_object.touch
      results << result_hash(UPDATED_DB_OBJECT_TIMESTAMP_ONLY, db_object.class.name)
    end
    results
  end

  def result_hash(response_code, addl=nil)
    { response_code => result_code_msg(response_code, addl) }
  end

  def result_code_msg(response_code, addl=nil)
    arg_hash = { incoming_version: incoming_version }
    if addl.is_a?(Hash)
      arg_hash.merge!(addl)
    else
      arg_hash[:addl] = addl
    end

    "#{result_msg_prefix} #{RESPONSE_CODE_TO_MESSAGES[response_code] % arg_hash}"
  end

  def result_msg_prefix
    @msg_prefix ||= "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size}, #{endpoint})"
  end

  # results = [result1, result2]
  # result1 = {response_code => msg}
  # result2 = {response_code => msg}
  def log_results(results)
    results.each do |r|
      severity = logger_severity_level(r.keys.first)
      msg = r.values.first
      Rails.logger.log(severity, msg)
    end
  end

  def logger_severity_level(result_code)
    case result_code
    when INVALID_ARGUMENTS then Logger::ERROR
    when VERSION_MATCHES then Logger::INFO
    when ARG_VERSION_GREATER_THAN_DB_OBJECT then Logger::INFO
    when ARG_VERSION_LESS_THAN_DB_OBJECT then Logger::ERROR
    when UPDATED_DB_OBJECT then Logger::INFO
    when UPDATED_DB_OBJECT_TIMESTAMP_ONLY then Logger::INFO
    when CREATED_NEW_OBJECT then Logger::INFO
    when DB_UPDATE_FAILED then Logger::ERROR
    when OBJECT_ALREADY_EXISTS then Logger::ERROR
    when OBJECT_DOES_NOT_EXIST then Logger::ERROR
    when PC_STATUS_CHANGED then Logger::INFO
    when UNEXPECTED_VERSION then Logger::ERROR
    when INVALID_MOAB then Logger::ERROR
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
