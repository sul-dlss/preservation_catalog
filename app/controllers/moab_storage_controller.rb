require 'moab/stanford'

# API to retrieve data from Moab Object Store
class MoabStorageController < ApplicationController
  def index
    @stored_druids = druids_from_storage_root
    respond_to do |format|
      format.xml { render xml: @stored_druids }
      format.all { render json: @stored_druids, content_type: 'application/json' }
    end
  end

  def show
    version_metadata_file = Stanford::StorageServices.version_metadata(params['id'])
    vm = Moab::VersionMetadata.parse(version_metadata_file.read)
    # FIXME: moab gem likely has a better way to get the latest version (github issue #24)
    @output = { current_version: vm.versions.last.version_id }
    respond_to do |format|
      format.xml { render xml: @output }
      format.all { render json: @output, content_type: 'application/json' }
    end
  end

  private

  def druids_from_storage_root
    @druids ||= begin
      @storage_root ||= "#{Moab::Config.storage_roots}/#{Moab::Config.storage_trunk}"
      Dir.glob("#{@storage_root}/**/[a-z][a-z]*[0-9]").map { |d| d.split("/").last }
    end
  end

end
