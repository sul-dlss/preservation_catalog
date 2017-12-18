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
      create_db_objects(PreservedCopy::DEFAULT_STATUS, true)
    else
      create_db_objects(PreservedCopy::INVALID_MOAB_STATUS, true)
    end

    handler_results.log_results
    handler_results.result_array
  end

  def create
    if invalid?
      handler_results.add_result(PreservedObjectHandlerResults::INVALID_ARGUMENTS, errors.full_messages)
    elsif PreservedObject.exists?(druid: druid)
      handler_results.add_result(PreservedObjectHandlerResults::OBJECT_ALREADY_EXISTS, 'PreservedObject')
    else
      create_db_objects(PreservedCopy::DEFAULT_STATUS)
    end

    handler_results.log_results
    handler_results.result_array
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

          if pres_copy.version != pres_object.current_version
            handler_results.add_result(PreservedObjectHandlerResults::PC_PO_VERSION_MISMATCH, { pc_version: pres_copy.version, po_version: pres_object.current_version })
            raise ActiveRecord::Rollback, "PO current_version #{pres_object.current_version} != PC version #{pres_copy.version}"
          end

          if incoming_version == pres_copy.version
            handler_results.add_result(PreservedObjectHandlerResults::VERSION_MATCHES, pres_copy.class.name)
            handler_results.add_result(PreservedObjectHandlerResults::VERSION_MATCHES, pres_object.class.name)
            update_pc_validation_timestamps(pres_copy)
            update_db_object(pres_copy)
          else
            version_comp_result = if incoming_version > pres_copy.version
                                    PreservedObjectHandlerResults::ARG_VERSION_GREATER_THAN_DB_OBJECT
                                  else
                                    PreservedObjectHandlerResults::ARG_VERSION_LESS_THAN_DB_OBJECT
                                  end
            handler_results.add_result(version_comp_result, pres_copy.class.name)
            handler_results.add_result(version_comp_result, pres_object.class.name)
            if moab_validation_errors.empty?
              update_preserved_copy_version_etc(pres_copy, incoming_version, incoming_size, true)
              update_status(pres_copy, PreservedCopy::OK_STATUS)
              update_db_object(pres_copy)
              pres_object.current_version = incoming_version
              update_db_object(pres_object)
            else
              update_status(pres_copy, PreservedCopy::INVALID_MOAB_STATUS)
              update_pc_validation_timestamps(pres_copy)
              update_db_object(pres_copy)
            end
          end
        end
        handler_results.remove_db_updated_results unless transaction_ok
      elsif endpoint.endpoint_type.endpoint_class == 'archive'
        # TODO: note that an endpoint PC version might not match PO.current_version
      end
    else
      handler_results.add_result(PreservedObjectHandlerResults::OBJECT_DOES_NOT_EXIST, 'PreservedObject')
      if moab_validation_errors.empty?
        create_db_objects(PreservedCopy::DEFAULT_STATUS, true)
      else
        create_db_objects(PreservedCopy::INVALID_MOAB_STATUS, true)
      end
    end
    handler_results.log_results
    handler_results.result_array
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

    handler_results.log_results
    handler_results.result_array
  end

  def update_version_after_validation
    if invalid?
      handler_results.add_result(PreservedObjectHandlerResults::INVALID_ARGUMENTS, errors.full_messages)
    else
      Rails.logger.debug "update_version_after_validation #{druid} called"
      if endpoint.endpoint_type.endpoint_class == 'online'
        # NOTE: we deal with active record transactions in update_online_version, not here
        if moab_validation_errors.empty?
          update_online_version(true, PreservedCopy::OK_STATUS)
        else
          update_online_version(true, PreservedCopy::INVALID_MOAB_STATUS)
        end
      elsif endpoint.endpoint_type.endpoint_class == 'archive'
        # TODO: perform archive object validation; then create a new PC record for the new
        #  archived version on the endpoint
      end
    end

    handler_results.log_results
    handler_results.result_array
  end

  def update_version
    if invalid?
      handler_results.add_result(PreservedObjectHandlerResults::INVALID_ARGUMENTS, errors.full_messages)
    else
      Rails.logger.debug "update_version #{druid} called"
      if endpoint.endpoint_type.endpoint_class == 'online'
        # NOTE: we deal with active record transactions in update_online_version, not here
        update_online_version
      elsif endpoint.endpoint_type.endpoint_class == 'archive'
        # TODO: create a new PC record for the new archived version on the endpoint
      end
    end

    handler_results.log_results
    handler_results.result_array
  end

  private

  def moab_validation_errors
    object_dir = "#{storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}"
    moab = Moab::StorageObject.new(druid, object_dir)
    object_validator = Stanford::StorageObjectValidator.new(moab)
    moab_errors = object_validator.validation_errors(Settings.moab.allow_content_subdirs)
    if moab_errors.any?
      moab_error_msgs = []
      moab_errors.each do |error_hash|
        error_hash.each_value { |msg| moab_error_msgs << msg }
      end
      handler_results.add_result(PreservedObjectHandlerResults::INVALID_MOAB, moab_error_msgs)
    end
    moab_errors
  end

  def create_db_objects(status, validated=false)
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

      if validated
        t = Time.current
        # Returns the value of time as an integer number of seconds since the Epoch.
        pc_attrs[:last_audited] = t.to_i
        pc_attrs[:last_checked_on_storage] = t
      end
      PreservedCopy.create!(pc_attrs)
    end

    handler_results.add_result(PreservedObjectHandlerResults::CREATED_NEW_OBJECT) if transaction_ok
  end

  # TODO: this is "too complex" per rubocop: shameless green implementation
  # NOTE: if we can reduce complexity, remove Metrics/PerceivedComplexity exception in .rubocop.yml
  def update_online_version(validated=false, status=nil)
    transaction_ok = with_active_record_transaction_and_rescue do
      pres_object = PreservedObject.find_by!(druid: druid)
      pres_copy = PreservedCopy.find_by!(preserved_object: pres_object, endpoint: endpoint) if pres_object
      # FIXME: what if there is more than one associated pres_copy?
      if incoming_version > pres_copy.version && pres_copy.version == pres_object.current_version
        # add result codes about object state w/o touching DB
        handler_results.add_result(
          PreservedObjectHandlerResults::ARG_VERSION_GREATER_THAN_DB_OBJECT, pres_copy.class.name
        )
        handler_results.add_result(
          PreservedObjectHandlerResults::ARG_VERSION_GREATER_THAN_DB_OBJECT, pres_object.class.name
        )

        update_preserved_copy_version_etc(pres_copy, incoming_version, incoming_size, validated)
        update_status(pres_copy, status) if status
        update_db_object(pres_copy)
        pres_object.current_version = incoming_version
        update_db_object(pres_object)
      else
        # add result codes about object state w/o touching DB
        handler_results.add_result(PreservedObjectHandlerResults::UNEXPECTED_VERSION, 'PreservedCopy')
        version_comparison_results(pres_copy, :version)
        version_comparison_results(pres_object, :current_version)

        update_status(pres_copy, status) if status
        update_pc_validation_timestamps(pres_copy) if validated
        update_db_object(pres_copy) if pres_copy.changed?
      end
    end

    handler_results.remove_db_updated_results unless transaction_ok
  end

  # shameless green implementation
  def confirm_online_version
    transaction_ok = with_active_record_transaction_and_rescue do
      pres_object = PreservedObject.find_by!(druid: druid)
      # FIXME: what if there is more than one associated pres_copy?
      pres_copy = PreservedCopy.find_by!(preserved_object: pres_object, endpoint: endpoint) if pres_object

      if pres_copy.version != pres_object.current_version
        handler_results.add_result(PreservedObjectHandlerResults::PC_PO_VERSION_MISMATCH, { pc_version: pres_copy.version, po_version: pres_object.current_version })
        raise ActiveRecord::Rollback, 'PO current_version != PC version'
      end

      if incoming_version == pres_copy.version
        handler_results.add_result(PreservedObjectHandlerResults::VERSION_MATCHES, pres_copy.class.name)
        handler_results.add_result(PreservedObjectHandlerResults::VERSION_MATCHES, pres_object.class.name)
      else
        handler_results.add_result(PreservedObjectHandlerResults::UNEXPECTED_VERSION, pres_copy.class.name)
        update_status(pres_copy, PreservedCopy::EXPECTED_VERS_NOT_FOUND_ON_STORAGE_STATUS)
      end
      update_pc_validation_timestamps(pres_copy)
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
