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
    @output = { current_version: Stanford::StorageServices.current_version(params['id']) }
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
