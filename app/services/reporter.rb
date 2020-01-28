# frozen_string_literal: true

require 'csv'

##
# run queries and produce reports from the results, for consumption
# by preservation catalog maintainers
class Reporter
  # @param [String] the name of the storage root for which druids should be listed
  # @return [String] the name of the CSV file to which the list was written
  def self.moab_storage_root_druid_list_to_csv(storage_root_name:, csv_filename: nil)
    msr = MoabStorageRoot.find_by!(name: storage_root_name) # fail fast if given a bad storage root name

    csv_filename ||= default_filename(filename_prefix: "MoabStorageRoot_#{storage_root_name}_druids", filename_suffix: 'csv')
    raise "#{csv_filename} already exists, aborting!" if FileTest.exist?(csv_filename)

    ensure_containing_dir(csv_filename)
    CSV.open(csv_filename, 'w') do |csv|
      PreservedObject
        .joins(:complete_moabs)
        .where(complete_moabs: { moab_storage_root: msr })
        .select(:druid)
        .order(:druid)
        .each_row do |po_hash| # #each_row is from postgresql_cursor gem
          csv << [po_hash['druid']]
        end
    end

    csv_filename
  end

  def self.default_filename(filename_prefix:, filename_suffix:)
    File.join(default_filepath, "#{filename_prefix}_#{DateTime.now.utc.iso8601}.#{filename_suffix}")
  end

  def self.default_filepath
    File.join(Rails.root, 'log', 'reports')
  end

  def self.ensure_containing_dir(filename)
    basename_len = File.basename(filename).length
    filepath_str = filename[0..-(basename_len + 1)] # add 1 to basename_len because ending at -1 gets the whole string
    FileUtils.mkdir_p(filepath_str) unless FileTest.exist?(filepath_str)
  end
end
