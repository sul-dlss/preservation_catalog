# API to retrieve data from Moab Object Store
class MoabStorageController < ApplicationController

  def index
    storage_root = 'spec/fixtures/moab_storage_root'
    @stored_druids = Dir.entries(storage_root).select { |e| e.match(/^[a-z]{2}\d{3}[a-z]{2}\d{4}$/i)  }

    respond_to do |format|
      format.xml { render xml: @stored_druids }
      format.all { render json: @stored_druids, content_type: 'application/json' }
    end
  end
end
