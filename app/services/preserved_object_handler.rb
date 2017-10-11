# creating a PreservedObject and/or updating check timestamps may require interactions
#  beyond the single PreservedObject model (e.g. PreservationCopy, PreservationPolicy).
#  This service class encapsulates logic to keep the controller and the model object
#    code simpler/thinner.
# NOTE: performing validation here to allow this class to be called directly avoiding http overhead
#
# inspired by http://www.thegreatcodeadventure.com/smarter-rails-services-with-active-record-modules/
class PreservedObjectHandler

  INVALID_ARGUMENTS = 1
  PO_VERSION_MATCHES = 2
  ARG_VERSION_GREATER_THAN_PO_DB_OBJECT = 3
  ARG_VERSION_LESS_THAN_PO_DB_OBJECT = 4
  UPDATED_DB_OBJECT = 5
  UPDATED_DB_OBJECT_TIMESTAMP_ONLY = 6
  CREATED_NEW_OBJECT = 7
  DB_UPDATE_FAILED = 8
  OBJECT_ALREADY_EXISTS = 9
  OBJECT_DOES_NOT_EXIST = 10
  PC_VERSION_MATCHES = 11
  ARG_VERSION_GREATER_THAN_PC_DB_OBJECT = 12
  ARG_VERSION_LESS_THAN_PC_DB_OBJECT = 13

  RESPONSE_CODE_TO_MESSAGES = {
    INVALID_ARGUMENTS => "encountered validation error(s): %{addl}",
    PO_VERSION_MATCHES => "incoming version (%{incoming_version}) matches preserved object db version",
    ARG_VERSION_GREATER_THAN_PO_DB_OBJECT => "incoming version (%{incoming_version}) greater than preserved object db version",
    ARG_VERSION_LESS_THAN_PO_DB_OBJECT => "incoming version (%{incoming_version}) less than preserved object db version; ERROR!",
    UPDATED_DB_OBJECT => "db object updated",
    UPDATED_DB_OBJECT_TIMESTAMP_ONLY => "updated db timestamp only",
    CREATED_NEW_OBJECT => "added object to db as it did not exist",
    DB_UPDATE_FAILED => "db update failed: %{addl}",
    OBJECT_ALREADY_EXISTS => "db object already exists",
    OBJECT_DOES_NOT_EXIST => "db object does not exist",
    PC_VERSION_MATCHES => "incoming version (%{incoming_version}) matches preservation copy db version",
    ARG_VERSION_GREATER_THAN_PC_DB_OBJECT => "incoming version (%{incoming_version}) greater than preservation copy db version",
    ARG_VERSION_LESS_THAN_PC_DB_OBJECT => "incoming version (%{incoming_version}) less than preservation copy db version; ERROR!"

  }.freeze

  include ActiveModel::Validations

  # Note: supplying validations here to allow validation before use, e.g. incoming_version in numeric logic
  validates :druid, presence: true, format: { with: /\A[a-z]{2}[0-9]{3}[a-z]{2}[0-9]{4}\z/ }
  validates :incoming_version, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :incoming_size, numericality: { only_integer: true, greater_than: 0 }
  validates :endpoint, presence: true

  attr_reader :druid, :incoming_version, :incoming_size, :storage_dir, :endpoint

  def initialize(druid, incoming_version, incoming_size, storage_dir)
    @druid = druid
    @incoming_version = version_string_to_int(incoming_version)
    @incoming_size = string_to_int(incoming_size)
    @storage_dir = storage_dir
    @endpoint = Endpoint.find_by(storage_location: storage_dir)
  end

  def create
    results = []
    if invalid?
      results << results_hash(INVALID_ARGUMENTS, errors.full_messages)
    elsif PreservedObject.exists?(druid: druid)
      results << result_hash(OBJECT_ALREADY_EXISTS)
    else
      pp_default = PreservationPolicy.default_preservation_policy
      po = PreservedObject.create!(druid: druid,
                             current_version: incoming_version,
                             size: incoming_size,
                             preservation_policy: pp_default)
      status = Status.find_by(status_text: "ok") # TODO: Replace the status_text to get a default status_text
      PreservationCopy.create(preserved_object: po, 
                          current_version: incoming_version, 
                          last_audited: nil, 
                          endpoint: endpoint, 
                          status: status, 
                          last_checked_on_storage: nil)
      results << result_hash(CREATED_NEW_OBJECT)
    end
    results.flatten!
    log_results(results)
    results
  end

  def update
    results = []
    if invalid?
      results << result_hash(INVALID_ARGUMENTS, errors.full_messages)
    elsif !PreservedObject.exists?(druid: druid)
      results << result_hash(OBJECT_DOES_NOT_EXIST)
    else 
      Rails.logger.debug "update #{druid} called and object exists"
      db_object = PreservedObject.find_by(druid: druid)
      results << update_per_version_comparison_po(db_object)
      pc_db_object = PreservationCopy.find_by(preserved_object: db_object, endpoint: endpoint)
      results << update_per_version_comparison_pc(pc_db_object)
    end
    results.flatten!
    log_results(results)
    results
  end

  def update_or_create
    results = []
    if invalid?
      results << result_hash(INVALID_ARGUMENTS, errors.full_messages)
    elsif PreservedObject.exists?(druid: druid)
      Rails.logger.debug "update #{druid} called and object exists"
      db_object = PreservedObject.find_by(druid: druid)
      results << update_per_version_comparison(db_object)
    else
      pp_default = PreservationPolicy.default_preservation_policy
      PreservedObject.create(druid: druid,
                             current_version: incoming_version,
                             size: incoming_size,
                             preservation_policy: pp_default)
      results << result_hash(CREATED_NEW_OBJECT)
    end
    results.flatten!
    log_results(results)
    results
  end

  private
  # expects @incoming_version to be numeric
  # TODO: update existence check timestamps/status per each flavor of comparison?
  def update_per_version_comparison_po(db_object)
    version_comparison = db_object.current_version <=> incoming_version
    results = []
    if version_comparison.zero?
      results << result_hash(PO_VERSION_MATCHES)
    elsif version_comparison == 1
      # TODO: needs manual intervention until automatic recovery services implemented
      results << result_hash(ARG_VERSION_LESS_THAN_PO_DB_OBJECT)
    elsif version_comparison == -1
      db_object.current_version = incoming_version
      db_object.size = incoming_size if incoming_size
      results << result_hash(ARG_VERSION_GREATER_THAN_PO_DB_OBJECT)
    end
    update_db_object(db_object, results)
    results.flatten
  end

  def update_per_version_comparison_pc(db_object)
    version_comparison = db_object.current_version <=> incoming_version
    results = []
    if version_comparison.zero?
      results << result_hash(PC_VERSION_MATCHES) 
    elsif version_comparison == 1
      # TODO: needs manual intervention until automatic recovery services implemented
      results << result_hash(ARG_VERSION_LESS_THAN_PC_DB_OBJECT)
    elsif version_comparison == -1
      db_object.current_version = incoming_version
      results << result_hash(ARG_VERSION_GREATER_THAN_PC_DB_OBJECT)
    end
    update_db_object(db_object, results)
    results.flatten
  end

  # TODO: this may need reworking if we need to distinguish db timestamp updates when
  #   version matched vs. incoming version less than db object
  def update_db_object(db_object, results)
    if db_object.changed?
      db_object.save
      results << result_hash(UPDATED_DB_OBJECT)
    else
      # FIXME: we may not want to do this, but instead to update specific timestamp for check
      db_object.touch
      results << result_hash(UPDATED_DB_OBJECT_TIMESTAMP_ONLY)
    end
  rescue ActiveRecord::ActiveRecordError => e
    results << result_hash(DB_UPDATE_FAILED, "#{e.inspect} #{e.message} #{e.backtrace.inspect}")
  end

  def result_hash(response_code, addl=nil)
    { response_code => result_code_msg(response_code, addl) }
  end

  def result_code_msg(response_code, addl=nil)
    "#{result_msg_prefix} #{RESPONSE_CODE_TO_MESSAGES[response_code] % { incoming_version: incoming_version, addl: addl }}"
  end

  def result_msg_prefix
    @msg_prefix ||= "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size}, #{storage_dir})"
  end

  # results = [result1, result2]
  # result1 = {response_code => msg}
  # result2 = {response_code => msg}
  def log_results(results)
    results.each do |r|
      severity = logger_severity_level(r.keys.first)
      msg = r.values.first
      # Rails.logger.log(severity, msg, 'PreservedObjectHandler')
      Rails.logger.log(severity, msg)
    end
  end

  def logger_severity_level(result_code)
    case result_code
    when INVALID_ARGUMENTS then Logger::ERROR
    when PO_VERSION_MATCHES then Logger::INFO
    when ARG_VERSION_GREATER_THAN_PO_DB_OBJECT then Logger::INFO
    when ARG_VERSION_LESS_THAN_PO_DB_OBJECT then Logger::ERROR
    when PC_VERSION_MATCHES then Logger::INFO
    when ARG_VERSION_GREATER_THAN_PC_DB_OBJECT then Logger::INFO
    when ARG_VERSION_LESS_THAN_PC_DB_OBJECT then Logger::ERROR
    when UPDATED_DB_OBJECT then Logger::INFO
    when UPDATED_DB_OBJECT_TIMESTAMP_ONLY then Logger::INFO
    when CREATED_NEW_OBJECT then Logger::WARN
    when DB_UPDATE_FAILED then Logger::ERROR
    when OBJECT_ALREADY_EXISTS then Logger::ERROR
    when OBJECT_DOES_NOT_EXIST then Logger::ERROR
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
