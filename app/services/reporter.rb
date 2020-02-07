# frozen_string_literal: true

require 'csv'

##
# run queries and produce reports from the results, for consumption
# by preservation catalog maintainers
class Reporter
  attr_reader :storage_root

  # @param [String] the name of the storage root to initialize for reporter
  # @return [Reporter] the reporter
  def initialize(params)
    @storage_root = MoabStorageRoot.find_by!(name: params[:storage_root_name])
  end

  def output_file
    default_filename(filename_prefix: "MoabStorageRoot_#{storage_root.name}_druids", filename_suffix: 'csv')
    # raise "#{output_file} already exists, aborting!" if FileTest.exist?(output_file)
  end

  # @param [String] the name of the storage root for which druids should be listed
  # @return [String] the name of the CSV file to which the list was written
  def moab_storage_root_druid_list_to_csv
    CSV.open(output_file, 'w') do |csv|
      storage_root.complete_moabs.each do |cm|
        csv << [cm.preserved_object.druid]
      end
    end

    output_file
  end

  def moab_storage_root_druid_details_to_csv
    CSV.open(output_file, 'w') do |csv|
      storage_root.complete_moabs.each do |cm|
        csv << [cm.preserved_object.druid, cm.status, cm.moab_storage_root.name, cm.from_moab_storage_root&.name]
      end
    end

    output_file
  end

  def moab_storage_root_audit_errors_to_csv
    CSV.open(output_file, 'w') do |csv|
      msr.complete_moabs.where.not(status: 'ok').each do |cm|
        csv << [cm.preserved_object.druid, cm.status, cm.moab_storage_root.name, cm.from_moab_storage_root&.name]
      end
    end

    output_file
  end

  def default_filename(filename_prefix:, filename_suffix:)
    File.join(default_filepath, "#{filename_prefix}_#{DateTime.now.utc.iso8601}.#{filename_suffix}")
  end

  def default_filepath
    File.join(Rails.root, 'log', 'reports')
  end

  def self.ensure_containing_dir(filename)
    basename_len = File.basename(filename).length
    filepath_str = filename[0..-(basename_len + 1)] # add 1 to basename_len because ending at -1 gets the whole string
    FileUtils.mkdir_p(filepath_str) unless FileTest.exist?(filepath_str)
  end
end
