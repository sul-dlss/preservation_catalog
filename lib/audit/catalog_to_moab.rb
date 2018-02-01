require 'druid-tools'
require 'profiler.rb'

# Catalog to Moab existence check code
class CatalogToMoab

  # allows for sharding/parallelization by storage_dir
  def self.check_version_on_dir(last_checked_b4_date, storage_dir)
    # TODO: ensure last_checked_version_b4_date is in the right format for query - see #485
    pcs = PreservedCopy
          .joins(:endpoint)
          .where(endpoints: { storage_location: storage_dir })
          .where('last_version_audit IS NULL or last_version_audit < ?', last_checked_b4_date)
          .order('last_version_audit IS NOT NULL, last_version_audit ASC')
    pcs.find_each do |pc|
      c2m = CatalogToMoab.new(pc, storage_dir)
      c2m.check_catalog_version
    end
  end

  def self.check_version_on_dir_profiled(last_checked_b4_date, storage_dir)
    profiler = Profiler.new
    profiler.prof { check_version_on_dir(last_checked_b4_date, storage_dir) }
    profiler.print_results_flat('C2M_check_version_on_dir')
  end

  def self.check_version_all_dirs(last_checked_b4_date)
    # FIXME: ensure last_checked_version_b4_date is in the right format - see #485
    Settings.moab.storage_roots.each do |strg_root_name, strg_root_location|
      start_msg = "#{Time.now.utc.iso8601} C2M check_version starting for '#{strg_root_name}' at #{strg_root_location}"
      puts start_msg
      Rails.logger.info start_msg
      check_version_on_dir(last_checked_b4_date, "#{strg_root_location}/#{Settings.moab.storage_trunk}")
      end_msg = "#{Time.now.utc.iso8601} C2M check_version ended for '#{strg_root_name}' at #{strg_root_location}"
      puts end_msg
      Rails.logger.info end_msg
    end
  end

  def self.check_version_all_dirs_profiled(last_checked_b4_date)
    profiler = Profiler.new
    profiler.prof { check_version_all_dirs(last_checked_b4_date) }
    profiler.print_results_flat('C2M_check_version_all_dirs')
  end

  # ----  INSTANCE code below this line ---------------------------

  attr_reader :preserved_copy, :storage_dir, :druid, :results, :moab

  def initialize(preserved_copy, storage_dir)
    @preserved_copy = preserved_copy
    @storage_dir = storage_dir
    @druid = preserved_copy.preserved_object.druid
    @results = AuditResults.new(druid, nil, preserved_copy.endpoint)
  end

  # shameless green implementation
  def check_catalog_version
    results.check_name = 'check_catalog_version'
    unless preserved_copy.matches_po_current_version?
      results.add_result(AuditResults::PC_PO_VERSION_MISMATCH,
                         pc_version: preserved_copy.version,
                         po_version: preserved_copy.preserved_object.current_version)
      return
    end

    unless online_moab_found?(druid, storage_dir)
      update_status(PreservedCopy::ONLINE_MOAB_NOT_FOUND_STATUS)
      results.add_result(AuditResults::ONLINE_MOAB_DOES_NOT_EXIST)
      results.report_results
      preserved_copy.save!
      return
    end

    moab_version = moab.current_version_id
    results.actual_version = moab_version
    catalog_version = preserved_copy.version
    if catalog_version == moab_version
      set_status_as_seen_on_disk(true) unless preserved_copy.status == PreservedCopy::OK_STATUS
      results.add_result(AuditResults::VERSION_MATCHES, preserved_copy.class.name)
      results.report_results
    elsif catalog_version < moab_version
      set_status_as_seen_on_disk(true)
      results.add_result(AuditResults::UNEXPECTED_VERSION, preserved_copy.class.name)
      # TODO: avoid repetitious results ... (leave out line above??) - see #484
      pohandler = PreservedObjectHandler.new(druid, moab_version, moab.size, preserved_copy.endpoint)
      pohandler.update_version_after_validation # results reported by this call
    else # catalog_version > moab_version
      set_status_as_seen_on_disk(false)
      results.add_result(AuditResults::UNEXPECTED_VERSION, preserved_copy.class.name)
      results.report_results
    end

    preserved_copy.update_audit_timestamps(ran_moab_validation?, true)
    preserved_copy.save!
  end

  private

  # TODO: near duplicate of method in POHandler - extract superclass or moab wrapper class?
  def moab_validation_errors
    @moab_errors ||=
      begin
        object_validator = Stanford::StorageObjectValidator.new(moab)
        moab_errors = object_validator.validation_errors(Settings.moab.allow_content_subdirs)
        @ran_moab_validation = true
        if moab_errors.any?
          moab_error_msgs = []
          moab_errors.each do |error_hash|
            error_hash.each_value { |msg| moab_error_msgs << msg }
          end
          results.add_result(AuditResults::INVALID_MOAB, moab_error_msgs)
        end
        moab_errors
      end
  end

  # TODO: duplicate of method in POHandler - extract superclass or moab wrapper class??
  def ran_moab_validation?
    @ran_moab_validation ||= false
  end

  # TODO: near duplicate of method in POHandler - extract superclass or moab wrapper class??
  def update_status(new_status)
    preserved_copy.update_status(new_status) do
      results.add_result(
        AuditResults::PC_STATUS_CHANGED,
        { old_status: preserved_copy.status, new_status: new_status }
      )
    end
  end

  def online_moab_found?(druid, storage_dir)
    @moab ||= begin
      object_dir = "#{storage_dir}/#{DruidTools::Druid.new(druid).tree.join('/')}"
      Moab::StorageObject.new(druid, object_dir)
    end
    return true if @moab
    false
  end

  # given whether the caller found the expected version of preserved_copy on disk, this will perform
  # other validations of what's on disk, and will update the status accordingly.
  # TODO: near duplicate of method in POHandler - extract superclass or moab wrapper class??
  def set_status_as_seen_on_disk(found_expected_version)
    if moab_validation_errors.any?
      update_status(PreservedCopy::INVALID_MOAB_STATUS)
      return
    end

    unless found_expected_version
      update_status(PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS)
      return
    end

    # TODO: do the check that'd set INVALID_CHECKSUM_STATUS

    update_status(PreservedCopy::OK_STATUS)
  end
end
