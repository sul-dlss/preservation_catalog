# frozen_string_literal: true

require 'csv'

##
# run queries and produce reports from the results, for consumption
# by preservation catalog maintainers
class Reporter
  attr_reader :storage_root

  # @params [Hash] params used to initialize the Reporter service
  # @return [Reporter] the reporter
  def initialize(params)
    @storage_root = MoabStorageRoot.find_by!(name: params[:storage_root_name])
  end

  def moab_storage_root_list_preserved_objects_relation
    PreservedObject
      .joins(:complete_moabs)
      .where(complete_moabs: { moab_storage_root: storage_root })
      .order(:druid)
  end

  # @return [Array] an array of druids on the storage root
  def druid_csv_list
    druid_array = [['druid']]
    moab_storage_root_list_preserved_objects_relation
      .select(:druid)
      .each_row do |po_hash|
        druid_array << [po_hash['druid']]
      end
    druid_array
  end

  # @param [Boolean] errors_only (default: false) - optionally only output lines with audit errors
  # @return [Array] an array of hashes with details for each druid provided
  def moab_detail_csv_list(errors_only: false)
    query = if errors_only
      moab_storage_root_list_preserved_objects_relation.where.not(complete_moabs: { status: 'ok' })
    else
      moab_storage_root_list_preserved_objects_relation
    end

    detail_array = [['druid', 'from_storage_root', 'storage_root', 'last_checksum_validation', 'last_moab_validation', 'status', 'status_details']]
    query.each_instance do |preserved_object|
      preserved_object.complete_moabs.each do |cm|
        detail_array << [
          preserved_object.druid, cm.from_moab_storage_root&.name, cm.moab_storage_root.name,
          cm.last_checksum_validation, cm.last_moab_validation, cm.status, cm.status_details
        ]
      end
    end
    detail_array
  end

  # @param [Array] lines - values to output on each line of the csv
  # @param [String] filename - optional filename to override the default
  # @return [String] the name of the CSV file to which the list was written
  def write_to_csv(lines, report_type: nil, filename: nil)
    raise ArgumentError, 'Must specify at least one of report_type or filename' unless report_type.present? || filename.present?

    filename ||= default_filename(filename_prefix: "MoabStorageRoot_#{storage_root.name}_#{report_type}", filename_suffix: 'csv')
    raise "#{filename} already exists, aborting!" if FileTest.exist?(filename)

    ensure_containing_dir(filename)
    CSV.open(filename, 'w') do |csv|
      lines.each do |line|
        csv << line
      end
    end

    filename
  end

  def default_filename(filename_prefix:, filename_suffix:)
    File.join(default_filepath, "#{filename_prefix}_#{DateTime.now.utc.iso8601}.#{filename_suffix}")
  end

  def default_filepath
    File.join(Rails.root, 'log', 'reports')
  end

  def ensure_containing_dir(filename)
    basename_len = File.basename(filename).length
    filepath_str = filename[0..-(basename_len + 1)] # add 1 to basename_len because ending at -1 gets the whole string
    FileUtils.mkdir_p(filepath_str) unless FileTest.exist?(filepath_str)
  end
end
