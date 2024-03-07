# frozen_string_literal: true

require 'zip'

# A class for exporting the original files from an old-style GIS item for
# reaccessioning with Preassembly.
class GisExporter
  attr_accessor :druid, :export_dir

  def self.export(druid, export_dir)
    new(druid, export_dir).run_export
  end

  def initialize(druid, export_dir)
    @druid = druid
    @export_dir = Pathname.new(export_dir)
  end

  def run_export
    raise ExportDirExists, "#{@export_dir} already exists" if Pathname.new(@export_dir).directory?
    raise MissingDataZip, "#{content_dir} doesn't contain data.zip" unless data_zip?
    FileUtils.mkdir_p(@export_dir)

    export_zip_files
    export_content_files
  end

  def export_zip_files
    data_zip_entries.each do |entry|
      File.open(@export_dir.join(entry.name), 'wb') do |output|
        entry.get_input_stream do |input|
          while (data = input.read(1024))
            output.write(data)
          end
        end
      end
    end
  end

  def export_content_files
    content_files.each do |path|
      # use copy_entry to copy directories if they are present (shouldn't be)
      FileUtils.copy_entry(path, @export_dir.join(path.basename))
    end
  end

  def item
    @item ||= Stanford::StorageServices.find_storage_object(@druid)
    raise "Unknown repository item: #{@driud}" unless @item
    @item
  end

  def item_version
    @item_version ||= item.current_version
  end

  def content_files
    content_dir.children.filter { |path| !path.basename.fnmatch('data.zip') }
  end

  def content_dir
    Pathname.new(item_version.version_pathname).join('data/content/')
  end

  def data_zip?
    data_zip_path.file?
  end

  def data_zip_path
    content_dir.join('data.zip')
  end

  def data_zip_entries
    Zip::File.new(data_zip_path).filter do |f|
      f.name !~ /-(iso19110|iso19139|fgdc).xml$/
    end
  end

  class Error < RuntimeError
  end

  class MissingDataZip < Error
  end

  class ExportDirExists < Error
  end
end
