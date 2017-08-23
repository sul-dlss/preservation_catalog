# API to retrieve data from Moab Object Store
class MoabStorageController < ApplicationController

  def index
    storage_root = 'spec/fixtures/moab_storage_root'
    @stored_druids = Dir.glob("#{storage_root}/**/[a-z][a-z]*[0-9]").map {|d| d.split("/").last}
    respond_to do |format|
      format.xml { render xml: @stored_druids }
      format.all { render json: @stored_druids, content_type: 'application/json' }
    end
  end
end
