# frozen_string_literal: true

class PreservedObjectsController < ApplicationController
  before_action :set_preserved_object, only: [:show]

  def show
    if @preserved_object
      render 'preserved_objects/show'
    else
      render plain: "PreservedObject with druid #{druid} not found", status: :not_found
    end
  end

  private

  def bare_druid
    druid.delete_prefix('druid:')
  end

  def druid
    params[:druid]
  end

  def set_preserved_object
    @preserved_object = PreservedObject.find_by(druid: bare_druid)
  end
end
