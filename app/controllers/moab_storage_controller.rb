# API to retrieve data from Moab Object Store
class MoabStorageController < ApplicationController
	require 'moab/stanford'
  def index
    storage_root = 'spec/fixtures/moab_storage_root'
    @stored_druids = Dir.entries(storage_root).select { |e| e.match(/^[a-z]{2}\d{3}[a-z]{2}\d{4}$/i)  }

    respond_to do |format|
      format.xml { render xml: @stored_druids }
      format.all { render json: @stored_druids, content_type: 'application/json' }
    end
  end
  def show
  	# storage_root = 'spec/fixtures/moab_storage_root'
   #  @stored_druids = Dir.entries(storage_root).select { |e| e.match(/^[a-z]{2}\d{3}[a-z]{2}\d{4}$/i)  }
    p "v^"*100
  	
  	# druid = @stored_druids[0]
  	druid = "dg806ms0373"
  	p File.dirname(__FILE__)

  	# Moab::Config.storage_roots = File.join(File.dirname(__FILE__),'..', '..', 'spec','fixtures')


  	Moab::Config.storage_roots = "/Users/sul.saravs/Desktop/preservation_core_catalog/spec/fixtures"
  	Moab::Config.storage_trunk = "moab_storage_root"

  	version_metadata_file = Stanford::StorageServices.version_metadata(druid)
  	vm = Moab::VersionMetadata.parse(version_metadata_file.read)
  	current_version = vm.versions.last.version_id
  	p current_version
  	p "^v"*100
  







  end


end
