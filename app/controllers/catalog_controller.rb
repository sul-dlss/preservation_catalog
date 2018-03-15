##
# CatalogController allows clients to manipulate the Object Inventory Catalog, e.g.
# to add an existing moab object to the catalog, or to update an entry for a moab object
# that's already in the catalog.
class CatalogController < ApplicationController

  attr_accessor :poh

  # POST /catalog
  def create
    druid = poh_params[:druid]
    incoming_version = poh_params[:incoming_version].to_i
    incoming_size = poh_params[:incoming_size].to_i
    endpoint = Endpoint.find(poh_params[:endpoint])
    @poh = PreservedObjectHandler.new(druid, incoming_version, incoming_size, endpoint)
    @poh.create
    # if @poh.result_array.include(whatever)
    #   return http 201
  end

  private

  # strong params / whitelist params
  def poh_params
    params.permit(:druid, :incoming_version, :incoming_size, :endpoint)
  end
end
