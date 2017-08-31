require 'moab/stanford'

##
# CatalogController allows clients to manipulate the Object Inventory Catalog, e.g.
# to add an existing moab object to the catalog, or to update an entry for a moab object
# that's already in the catalog.
class CatalogController < ApplicationController
  before_action :set_id

  def add_preserved_object
    PreservedObject.create!(
      druid: @id, size: moab_size(@id), current_version: Stanford::StorageServices.current_version(@id)
    )
  end

  def update_preserved_object
    preserved_obj = PreservedObject.find_by(druid: @id)
    preserved_obj.update_attributes(
      druid: @id, size: moab_size(@id), current_version: Stanford::StorageServices.current_version(@id)
    )
  end

  private

  def set_id
    @id = catalog_params[:id]
    head(:unprocessable_entity) if @id.blank?
  end

  def catalog_params
    params.permit(:id)
  end

  def moab_size(id)
    # TODO: make this actually get the size once there's a method for that.
    # for now, just using the id to quiet rubocop complaint.
    # https://github.com/sul-dlss/moab-versioning/issues/21
    42 || id
  end
end
