# PreservedObjectHandler results are an array of hash objects, like so:
#   results = [result1, result2]
#   result1 = {response_code => msg}
#   result2 = {response_code => msg}
#
# This class extracts out the result specific logic from PreservedObjectHandler to make the code more readable
class PreservedObjectHandlerResults

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
  PC_PO_VERSION_MISMATCH = 14

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
    INVALID_MOAB => "Invalid moab, validation errors: %{addl}",
    PC_PO_VERSION_MISMATCH => "PreservedCopy online moab version does not match PreservedObject current_version"
  }.freeze

  DB_UPDATED_CODES = [
    UPDATED_DB_OBJECT,
    UPDATED_DB_OBJECT_TIMESTAMP_ONLY,
    CREATED_NEW_OBJECT,
    PC_STATUS_CHANGED
  ].freeze

  def self.logger_severity_level(result_code)
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
    when PC_PO_VERSION_MISMATCH then Logger::ERROR
    end
  end

  attr_reader :result_array, :incoming_version, :msg_prefix

  def initialize(druid, incoming_version, incoming_size, endpoint)
    @incoming_version = incoming_version
    @msg_prefix = "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size}, #{endpoint})"
    @result_array = []
  end

  def add_result(code, msg_args=nil)
    result_array << result_hash(code, msg_args)
  end

  # used when updates wrapped in transaction fail, and there is a need to ensure there is no db updated result
  def remove_db_updated_results
    result_array.delete_if { |res_hash| DB_UPDATED_CODES.include?(res_hash.keys.first) }
  end

  def result_hash(code, msg_args=nil)
    { code => result_code_msg(code, msg_args) }
  end

  def contains_result_code?(code)
    result_array.detect { |result_hash| result_hash.keys.include?(code) } != nil
  end

  # result_array = [result1, result2]
  # result1 = {response_code => msg}
  # result2 = {response_code => msg}
  def log_results
    result_array.each do |r|
      severity = self.class.logger_severity_level(r.keys.first)
      msg = r.values.first
      Rails.logger.log(severity, msg)
    end
  end

  private

  def result_code_msg(code, addl=nil)
    arg_hash = { incoming_version: incoming_version }
    if addl.is_a?(Hash)
      arg_hash.merge!(addl)
    else
      arg_hash[:addl] = addl
    end

    "#{msg_prefix} #{RESPONSE_CODE_TO_MESSAGES[code] % arg_hash}"
  end
end
