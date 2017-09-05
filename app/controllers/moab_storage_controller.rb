require 'moab/stanford'
require 'action_view'
include ActionView::Helpers::NumberHelper

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
    moab_path = path_from_object_id(params['id'])
    object_size = directory_size(moab_path)
    object_size_human = number_to_human_size(object_size)
    @output = {
      current_version: Stanford::StorageServices.current_version(params['id']),
      object_size: object_size,
      object_size_human: object_size_human
    }
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

  def path_from_object_id(id)
    storage_repo = Stanford::StorageRepository.new
    storage_repo.find_storage_root(id).join(storage_repo.storage_trunk, storage_repo.storage_branch(id)).to_s
  end

  def directory_size(dirname)
    size = 0
    Find.find(dirname) do |path|
      if FileTest.directory?(path)
        Find.prune if File.basename(path)[0] == '.'
      else
        size += FileTest.size(path)
      end
    end
    size
  end
end
