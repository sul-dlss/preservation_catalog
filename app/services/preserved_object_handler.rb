# creating a PreservedObject and/or updating check timestamps may require interactions
#  beyond the single PreservedObject model (e.g. PreservedCopy, PreservationPolicy).
#  This service class encapsulates logic to keep the controller and the model object
#    code simpler/thinner.
# NOTE: performing validation here to allow this class to be called directly avoiding http overhead
#
# inspired by http://www.thegreatcodeadventure.com/smarter-rails-services-with-active-record-modules/
require 'pp'
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
    UNEXPECTED_VERSION => "incoming version (%{incoming_version}) has unexpected relationship to %{addl} db version; ERROR!"
  }.freeze

  include ActiveModel::Validations

  # Note: supplying validations here to allow validation before use, e.g. incoming_version in numeric logic
  validates :druid, presence: true, format: { with: DruidTools::Druid.pattern }
  validates :incoming_version, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :incoming_size, numericality: { only_integer: true, greater_than: 0 }
  validates :endpoint, presence: true

  attr_reader :druid, :incoming_version, :incoming_size, :storage_dir, :endpoint

  def initialize(druid, incoming_version, incoming_size, storage_dir)
    @druid = druid
    @incoming_version = version_string_to_int(incoming_version)
    @incoming_size = string_to_int(incoming_size)
    @storage_dir = storage_dir
    @endpoint = Endpoint.find_by(storage_location: storage_dir) # let the validations catch lack of endpoint
  end

  def create
    results = []
    if invalid?
      results << result_hash(INVALID_ARGUMENTS, errors.full_messages)
    elsif PreservedObject.exists?(druid: druid)
      results << result_hash(OBJECT_ALREADY_EXISTS, 'PreservedObject')
    else
      pp_default = PreservationPolicy.default_preservation_policy
      begin
        p '-----------------------------------------'
        p "storage_dir: #{storage_dir}"
        p "Druid: #{druid}"
        p "incoming_version: #{incoming_version}"
        druid_tool = DruidTools::Druid.new(druid)
        object_dir = "#{storage_dir}/#{druid_tool.tree.join('/')}"
        so = Moab::StorageObject.new(druid,object_dir)
        sov = Moab::StorageObjectValidator.new(so)

        pp sov.validation_errors
        p "Object_dir: #{object_dir}"
        p '-----------------------------------------'
        po = PreservedObject.create!(druid: druid,
                                     current_version: incoming_version,
                                     preservation_policy: pp_default)
        status = Status.default_status
        PreservedCopy.create!(preserved_object: po,
                              version: incoming_version,
                              size: incoming_size,
                              endpoint: endpoint,
                              status: status)
        results << result_hash(CREATED_NEW_OBJECT)
      rescue ActiveRecord::RecordNotFound => e
        results << result_hash(OBJECT_DOES_NOT_EXIST, e.inspect)
      rescue ActiveRecord::ActiveRecordError => e
        results << result_hash(DB_UPDATE_FAILED, "#{e.inspect} #{e.message} #{e.backtrace.inspect}")
      end
    end
    log_results(results)
    results
  end

  def confirm_version
    results = []
    if invalid?
      results << result_hash(INVALID_ARGUMENTS, errors.full_messages)
    else
      Rails.logger.debug "confirm_version #{druid} called and object exists"
      begin
        po_db_object = PreservedObject.find_by!(druid: druid)
        results.concat(confirm_version_on_db_object(po_db_object, :current_version))
        pc_db_object = PreservedCopy.find_by!(preserved_object: po_db_object, endpoint: endpoint)
        results.concat(confirm_version_on_db_object(pc_db_object, :version))
      rescue ActiveRecord::RecordNotFound => e
        results << result_hash(OBJECT_DOES_NOT_EXIST, e.inspect)
      rescue ActiveRecord::ActiveRecordError => e
        results << result_hash(DB_UPDATE_FAILED, "#{e.inspect} #{e.message} #{e.backtrace.inspect}")
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
      Rails.logger.debug "update_version #{druid} called and druid in Catalog"
      begin
        pres_object = PreservedObject.find_by!(druid: druid)
        pres_copy = PreservedCopy.find_by!(preserved_object: pres_object, endpoint: endpoint)
        if incoming_version > pres_copy.version
          # FIXME: only update PreservedCopy.version IFF it's Moab endpoint
          results << result_hash(ARG_VERSION_GREATER_THAN_DB_OBJECT, pres_copy.class.name)
          update_preserved_copy(pres_copy, incoming_version, incoming_size)
          results.concat(update_status(pres_copy, Status.default_status))
          results.concat(update_db_object(pres_copy))
          if incoming_version > pres_object.current_version # FIXME: need code/test for when it's NOT
            results << result_hash(ARG_VERSION_GREATER_THAN_DB_OBJECT, pres_object.class.name)
            update_preserved_object(pres_object, incoming_version)
            results.concat(update_db_object(pres_object))
          end
        else
          results << result_hash(UNEXPECTED_VERSION, 'PreservedCopy')
          results.concat(version_comparison_results(pres_copy, :version))
          results.concat(version_comparison_results(pres_object, :current_version))
          # FIXME: TODO: should it updat3e existence check timestamps/status?
        end
      rescue ActiveRecord::RecordNotFound => e
        results << result_hash(OBJECT_DOES_NOT_EXIST, e.inspect)
      rescue ActiveRecord::ActiveRecordError => e
        results << result_hash(DB_UPDATE_FAILED, "#{e.inspect} #{e.message} #{e.backtrace.inspect}")
      end
    end

    log_results(results)
    results
  end

  private

  # expects @incoming_version to be numeric
  def update_preserved_copy(pres_copy, new_version, new_size)
    pres_copy.version = new_version
    pres_copy.size = new_size if new_size
  end

  # expects @incoming_version to be numeric
  def update_preserved_object(pres_obj, new_version)
    pres_obj.current_version = new_version
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

  def increase_version(db_object)
    results = []

    results << result_hash(ARG_VERSION_GREATER_THAN_DB_OBJECT, db_object.class.name)
    if db_object.is_a?(PreservedCopy)
      update_preserved_copy(db_object, incoming_version, incoming_size)
      results.concat(update_status(db_object, Status.default_status))
    else
      update_preserved_object(db_object, incoming_version)
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
      db_object.save
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
    @msg_prefix ||= "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size}, #{storage_dir})"
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
