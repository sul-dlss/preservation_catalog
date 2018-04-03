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
    endpoint = Endpoint.find_by(endpoint_name: poh_params[:endpoint_name])
    @poh = PreservedObjectHandler.new(druid, incoming_version, incoming_size, endpoint)
    poh.create
    status_code =
      if poh.handler_results.contains_result_code?(:created_new_object)
        :created # 201
      elsif poh.handler_results.contains_result_code?(:db_obj_already_exists)
        :conflict # 409
      elsif poh.handler_results.contains_result_code?(:invalid_arguments)
        :not_acceptable # 406
      else
        :internal_server_error # 500
      end
    render status: status_code, json: poh.handler_results.to_json
  end

  private

  # strong params / whitelist params
  def poh_params
    params.permit(:druid, :incoming_version, :incoming_size, :endpoint_name)
  end
end
