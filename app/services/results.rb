# frozen_string_literal: true

# Results provides a general purpose data structure for services to track actions that are
# performed (e.g., created a new object) and states that are determined (e.g., a moab on disk is invalid).

# Results may indicate an error or may be merely informative.
# This is dependent on the context, so it is important to know what a result means, how it is
# created, and how it is used.

# In many cases, results are provided to ResultsReporters, which will selectively notify for some results.
# Notications include logging, HB alerting, and reporting a DSA event.

# Calling code may also take action based on the results. For example, CatalogController.create and
# CatalogController.update will use result to determine which HTTP status to return.

# All results are kept in the result_array attribute, which is returned by the report_results method.
#   result_array = [result1, result2]
#   result1 = {response_code => msg}
#   result2 = {response_code => msg}
class Results # rubocop:disable Metrics/ClassLength
  ACTUAL_VERS_GT_DB_OBJ = :actual_vers_gt_db_obj
  ACTUAL_VERS_LT_DB_OBJ = :actual_vers_lt_db_obj
  CREATED_NEW_OBJECT = :created_new_object
  DB_OBJ_ALREADY_EXISTS = :db_obj_already_exists
  DB_OBJ_DOES_NOT_EXIST = :db_obj_does_not_exist
  DB_UPDATE_FAILED = :db_update_failed
  # When PreservedObject.current_version and MoabRecord.version disagree
  DB_VERSIONS_DISAGREE = :db_versions_disagree
  FILE_NOT_IN_MANIFEST = :file_not_in_manifest
  FILE_NOT_IN_MOAB = :file_not_in_moab
  FILE_NOT_IN_SIGNATURE_CATALOG = :file_not_in_signature_catalog
  # When MoabRecordService::* invoked with invalid arguments
  INVALID_ARGUMENTS = :invalid_arguments
  INVALID_MANIFEST = :invalid_manifest
  INVALID_MOAB = :invalid_moab
  MANIFEST_NOT_IN_MOAB = :manifest_not_in_moab
  MOAB_CHECKSUM_VALID = :moab_checksum_valid
  MOAB_FILE_CHECKSUM_MISMATCH = :moab_file_checksum_mismatch
  # When moab not found on disk
  MOAB_NOT_FOUND = :moab_not_found
  MOAB_RECORD_STATUS_CHANGED = :moab_record_status_changed
  SIGNATURE_CATALOG_NOT_IN_MOAB = :signature_catalog_not_in_moab
  UNABLE_TO_CHECK_STATUS = :unable_to_check_status
  # When MoabRecord version does not match moab on disk
  UNEXPECTED_VERSION = :unexpected_version
  VERSION_MATCHES = :version_matches
  # When ZipPart md5 does not match local zip part file md5
  ZIP_PART_CHECKSUM_FILE_MISMATCH = :zip_part_checksum_file_mismatch
  # When ZipPart md5 does not match zip part file md5 on endpoint
  ZIP_PART_CHECKSUM_MISMATCH = :zip_part_checksum_mismatch
  # When expected zip part file not found on endpoint
  ZIP_PART_NOT_FOUND = :zip_part_not_found
  # When ZippedMoabVersion.zip_part_count != ZippedMoabVersion.zip_parts.count
  ZIP_PARTS_COUNT_DIFFERS_FROM_ACTUAL = :zip_parts_count_differs_from_actual
  # When total of ZipPart.size < Total of size of files for version on disk
  ZIP_PARTS_SIZE_INCONSISTENCY = :zip_parts_size_inconsistency
  ZIP_PARTS_NOT_ALL_REPLICATED = :zip_parts_not_all_replicated
  # When no ZipParts exist for a ZippedMoabVersion yet
  ZIP_PARTS_NOT_CREATED = :zip_parts_not_created

  RESPONSE_CODE_TO_MESSAGES = {
    ACTUAL_VERS_GT_DB_OBJ => 'actual version (%{actual_version}) greater than ' \
                             '%{db_obj_name} db version (%{db_obj_version})',
    ACTUAL_VERS_LT_DB_OBJ => 'actual version (%{actual_version}) less than ' \
                             '%{db_obj_name} db version (%{db_obj_version}); ERROR!',
    CREATED_NEW_OBJECT => 'added object to db as it did not exist',
    DB_OBJ_ALREADY_EXISTS => '%{addl} db object already exists',
    DB_OBJ_DOES_NOT_EXIST => '%{addl} db object does not exist',
    DB_UPDATE_FAILED => 'db update failed: %{addl}',
    DB_VERSIONS_DISAGREE => 'MoabRecord version %{moab_record_version} does not match ' \
                            'PreservedObject current_version %{po_version}',
    FILE_NOT_IN_MANIFEST => 'Moab file %{file_path} was not found in Moab manifest %{manifest_file_path}',
    FILE_NOT_IN_MOAB => '%{manifest_file_path} refers to file (%{file_path}) not found in Moab',
    FILE_NOT_IN_SIGNATURE_CATALOG => 'Moab file %{file_path} was not found in ' \
                                     'Moab signature catalog %{signature_catalog_path}',
    INVALID_ARGUMENTS => 'encountered validation error(s): %{addl}',
    INVALID_MANIFEST => 'unable to parse %{manifest_file_path} in Moab',
    INVALID_MOAB => 'Invalid Moab, validation errors: %{addl}',
    MANIFEST_NOT_IN_MOAB => '%{manifest_file_path} not found in Moab',
    MOAB_CHECKSUM_VALID => 'checksum(s) match',
    MOAB_FILE_CHECKSUM_MISMATCH => 'checksums or size for %{file_path} version ' \
                                   '%{version} do not match entry in latest signatureCatalog.xml.',
    MOAB_NOT_FOUND => 'db MoabRecord (created %{db_created_at}; last updated ' \
                      '%{db_updated_at}) exists but Moab not found',
    MOAB_RECORD_STATUS_CHANGED => 'MoabRecord status changed from %{old_status} to %{new_status}',
    SIGNATURE_CATALOG_NOT_IN_MOAB => '%{signature_catalog_path} not found in Moab',
    UNABLE_TO_CHECK_STATUS => 'unable to validate when MoabRecord status is %{current_status}',
    UNEXPECTED_VERSION => 'actual version (%{actual_version}) has unexpected ' \
                          'relationship to %{db_obj_name} db version (%{db_obj_version}); ERROR!',
    VERSION_MATCHES => 'actual version (%{actual_version}) matches %{addl} db version',
    ZIP_PART_CHECKSUM_FILE_MISMATCH => "%{s3_key} catalog md5 (%{md5}) doesn't match the local zip file md5 " \
                                       '(%{local_md5})',
    ZIP_PART_CHECKSUM_MISMATCH => 'replicated md5 mismatch on %{endpoint_name}: ' \
                                  "%{s3_key} catalog md5 (%{md5}) doesn't match the replicated md5 " \
                                  '(%{replicated_checksum}) on %{bucket_name}',
    ZIP_PART_NOT_FOUND => 'replicated part not found on %{endpoint_name}: ' \
                          '%{s3_key} was not found on %{bucket_name}',
    ZIP_PARTS_COUNT_DIFFERS_FROM_ACTUAL => '%{version} on %{endpoint_name}: ' \
                                           "ZippedMoabVersion stated parts count (%{db_count}) doesn't match actual " \
                                           'number of zip parts rows (%{actual_count})',
    ZIP_PARTS_SIZE_INCONSISTENCY => '%{version} on %{endpoint_name}: ' \
                                    'Sum of ZippedMoabVersion child part sizes (%{total_part_size}) is less than what is in ' \
                                    'the Moab: %{moab_version_size}',
    ZIP_PARTS_NOT_ALL_REPLICATED => '%{version} on %{endpoint_name}: not all ' \
                                    'ZippedMoabVersion parts are replicated yet',
    ZIP_PARTS_NOT_CREATED => '%{version} on %{endpoint_name}: no zip_parts exist yet for this ZippedMoabVersion'
  }.freeze

  DB_UPDATED_CODES = [
    CREATED_NEW_OBJECT,
    MOAB_RECORD_STATUS_CHANGED
  ].freeze

  attr_reader :druid, :moab_storage_root, :check_name, :actual_version

  delegate :empty?, :present?, :size, :map, :first, :each, :select, :find, to: :result_array

  def initialize(druid:, moab_storage_root:, actual_version: nil, check_name: nil)
    @druid = druid
    @actual_version = actual_version
    @moab_storage_root = moab_storage_root
    @check_name = check_name
    @result_array = []
  end

  def add_result(code, msg_args = nil)
    result_array << result_hash(code, msg_args)
  end

  # used when updates wrapped in transaction fail, and there is a need to ensure there is no db updated result
  def remove_db_updated_results
    result_array.delete_if { |res_hash| DB_UPDATED_CODES.include?(res_hash.keys.first) }
  end

  def to_a
    result_array.dup.freeze
  end

  def completed_results
    result_array.select { |result| status_changed_to_ok?(result) }.freeze
  end

  def error_results
    result_array.reject { |result| status_changed_to_ok?(result) }.freeze
  end

  def contains_result_code?(code)
    result_array.detect { |result_hash| result_hash.key?(code) } != nil
  end

  # this prioritizes getting everything on one grep-able line, which makes things less readable
  # at a glance on the terminal than if the values were joined by line breaks.
  def to_s
    "#{string_prefix} #{result_array.map(&:values).flatten.join(' && ')}"
  end

  def to_json(*_args)
    { druid: druid, results: result_array }.to_json
  end

  def result_summary_msg
    catchy_pass_fail_msg =
      if error_results.empty?
        '✅ fixity check passed'
      else
        '⚠️ fixity check failed, investigate errors'
      end

    "#{catchy_pass_fail_msg} - #{check_name} - #{druid} - #{location_version_string}"
  end

  private

  attr_reader :result_array

  def status_changed_to_ok?(result)
    /to ok$/.match?(result[Results::MOAB_RECORD_STATUS_CHANGED])
  end

  def result_hash(code, msg_args = nil)
    { code => result_code_msg(code, msg_args) }
  end

  def result_code_msg(code, addl = nil)
    arg_hash = { actual_version: actual_version }
    if addl.is_a?(Hash)
      arg_hash.merge!(addl)
    else
      arg_hash[:addl] = addl
    end
    RESPONSE_CODE_TO_MESSAGES[code] % arg_hash
  end

  def location_version_string
    @location_version_string ||= begin
      location_info = "actual location: #{moab_storage_root}" if moab_storage_root
      actual_version_info = "actual version: #{actual_version}" if actual_version
      "#{location_info}; #{actual_version_info}"
    end
  end

  def string_prefix
    @string_prefix ||= "#{check_name} (#{location_version_string})"
  end
end
