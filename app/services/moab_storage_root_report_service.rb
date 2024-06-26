# frozen_string_literal: true

##
# run queries and produce reports from the results, for consumption
# by preservation catalog maintainers
class MoabStorageRootReportService
  attr_reader :storage_root

  # @params [Hash] params used to initialize the MoabStorageRootReport service
  def initialize(params)
    @storage_root = MoabStorageRoot.find_by!(name: params[:storage_root_name])
    @msr_names = {}
  end

  # @return [Array<Array>] an array of arrays; each inner array represents a CSV row w/ a druid from the storage root. includes a header row.
  def druid_csv_list
    druid_array = [['druid']]
    moab_records_and_preserved_objects_in_storage_root
      .select(:druid)
      .each_row do |po_hash|
        druid_array << [po_hash['druid']]
      end
    druid_array
  end

  # @param [Boolean] errors_only (default: false) - optionally only output lines with audit errors
  # @return [Array<Array>] an array of arrays; each inner array represents a CSV row w/ details for each druid in query result.  includes header row.
  def moab_detail_csv_list(errors_only: false)
    query =
      if errors_only
        moab_records_and_preserved_objects_in_storage_root.where.not(moab_records: { status: 'ok' })
      else
        moab_records_and_preserved_objects_in_storage_root
      end

    header_row = ['druid',
                  'previous storage root',
                  'current storage root',
                  'last checksum validation',
                  'last moab validation',
                  'status',
                  'status details']

    cols = ['druid', 'from_moab_storage_root_id', 'last_checksum_validation', 'last_moab_validation', 'status AS status_code', 'status_details']
    data_rows = query.select(cols).each_row.map do |row_result_hash|
      [row_result_hash['druid'],
       moab_storage_root_name(row_result_hash['from_moab_storage_root_id']),
       storage_root.name,
       row_result_hash['last_checksum_validation'],
       row_result_hash['last_moab_validation'],
       status_text_from_code(row_result_hash['status_code']), # must translate underlying status enum value since we're not instantiating AR objects
       row_result_hash['status_details']]
    end
    [header_row] + data_rows # wrap header_row in a list to combine with data_rows list
  end

  # @param [Array<Array>] lines - lines to output to a .csv file.  CSV library expects each line it appends to be Array of cols, hence Array<Array>.
  # @param [String] report_tag - optional user specified text to insert into generated file name, for easier visual skimming of runs in a dir listing
  # @param [String] report_type - optional report type to use when constructing default filename.  ignored if filename param is provided.
  # @param [String] filename - optional filename to override the default.
  # @return [String] the name of the CSV file to which the list was written
  # @raise [ArgumentError] if neither report_type nor filename is provided
  # @raise [RuntimeError] if the file to be written to already exists
  def write_to_csv(lines, report_type: nil, report_tag: nil, filename: nil)
    raise ArgumentError, 'Must specify at least one of report_type or filename' if report_type.blank? && filename.blank?

    filename ||= default_filename(filename_prefix: "storage_#{storage_root.name}_#{report_type}", report_tag: report_tag)
    raise "#{filename} already exists, aborting!" if FileTest.exist?(filename)

    ensure_containing_dir(filename)
    CSV.open(filename, 'w') do |csv|
      lines.each do |line|
        csv << line
      end
    end

    filename
  end

  private

  def default_filepath
    Rails.root.join('log', 'reports')
  end

  def moab_storage_root_name(msr_id)
    return nil if msr_id.blank?
    @msr_names[msr_id] ||= MoabStorageRoot.find(msr_id).name
  end

  # TODO: make methods like this and #write_csv that don't leverage internal state into class methods
  def status_text_from_code(status_code)
    MoabRecord.statuses.key(status_code)
  end

  # @return [ActiveRecord::Relation] an AR Relation listing the MoabRecords (and some associated info) on a MoabStorageRoot, sorted by druid.
  #   we expect druids to be unique across a given storage root.
  def moab_records_and_preserved_objects_in_storage_root
    PreservedObject
      .joins(:moab_record)
      .where(moab_record: { moab_storage_root: storage_root })
      .order(:druid)
  end

  def default_filename(filename_prefix:, report_tag: nil)
    report_tag_str = report_tag.blank? ? nil : "_#{report_tag}"
    timestamp_str = DateTime.now.utc.iso8601.gsub(':', '') # colons are a pain to deal with on CLI, so just remove them
    File.join(default_filepath, "#{filename_prefix}#{report_tag_str}_#{timestamp_str}.csv")
  end

  def ensure_containing_dir(filename)
    basename_len = File.basename(filename).length
    filepath_str = filename[0..-(basename_len + 1)] # add 1 to basename_len because ending at -1 gets the whole string
    FileUtils.mkdir_p(filepath_str)
  end
end
