# frozen_string_literal: true

require 'csv'

##
# run queries and produce reports from the results, for consumption
# by preservation catalog maintainers
class Reporter
  attr_reader :storage_root, :druids

  # @param [String] the name of the storage root to initialize for reporter
  # @return [Reporter] the reporter
  def initialize(params)
    @storage_root = MoabStorageRoot.find_by!(name: params[:storage_root_name])
    @druids = []
  end

  # @return [Array] an array of druids on the storage root
  def moab_storage_root_druid_list
    PreservedObject
      .joins(:complete_moabs)
      .where(complete_moabs: { moab_storage_root: storage_root })
      .select(:druid, :status)
      .order(:druid)
      .each_row do |po_hash|
        @druids << po_hash['druid']
      end
  end

  # @param [Array] druids to output details for
  # @param [Boolean] optionally only output lines with audit errors
  # @return [Array] an array of hashes with details for each druid provided
  def moab_detail_for(data, errors_only: false)
    detail_array = []
    data.each do |druid|
      preserved_object = PreservedObject.find_by(druid: druid)
      preserved_object.complete_moabs.each do |cm|
        next if errors_only && cm.status == 'ok'
        detail_array << { druid: druid,
                          status: cm.status,
                          status_details: cm.status_details,
                          last_moab_validation: cm.last_moab_validation,
                          last_checksum_validation: cm.last_checksum_validation,
                          storage_root: cm.moab_storage_root.name,
                          from_storage_root: cm.from_moab_storage_root&.name }
      end
    end
    detail_array
  end

  # @param [Array] values to output on each line of the csv
  # @param [String] optional filename
  # @return [String] the name of the CSV file to which the list was written
  def write_to_csv(data, filename)
    filename ||= default_filename(filename_prefix: "MoabStorageRoot_#{storage_root.name}_druids", filename_suffix: 'csv')
    raise "#{filename} already exists, aborting!" if FileTest.exist?(filename)

    ensure_containing_dir(filename)
    CSV.open(filename, 'w') do |csv|
      data.each do |line|
        line = line.values if line.is_a? Hash
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
