##
# CatalogController allows consumers to interact with the Preservation Catalog, e.g.
# to add an existing moab object to the catalog, or to update an entry for a moab object
# that's already in the catalog.
class CatalogController < ApplicationController

  attr_accessor :poh

  # POST /catalog
  def create
    @poh = PreservedObjectHandler.new(bare_druid, incoming_version, incoming_size, moab_storage_root)
    poh.create(checksums_validated)
    status_code =
      if poh.results.contains_result_code?(:created_new_object)
        :created # 201
      elsif poh.results.contains_result_code?(:db_obj_already_exists)
        :conflict # 409
      elsif poh.results.contains_result_code?(:invalid_arguments)
        :not_acceptable # 406
      else
        :internal_server_error # 500
      end
    render status: status_code, json: poh.results.to_json
  end

  # PATCH /catalog/:id
  # User can only update a partial record (application controls what can be updated)
  def update
    @poh = PreservedObjectHandler.new(bare_druid, incoming_version, incoming_size, moab_storage_root)
    poh.update_version(checksums_validated)
    status_code =
      if poh.results.contains_result_code?(:actual_vers_gt_db_obj)
        :ok # 200
      elsif poh.results.contains_result_code?(:db_obj_does_not_exist)
        :not_found # 404
      elsif poh.results.contains_result_code?(:invalid_arguments)
        :not_acceptable # 406
      elsif poh.results.contains_result_code?(:actual_vers_lt_db_obj)
        :bad_request # 400
      else
        :internal_server_error # 500 including  :unexpected_version, :cm_po_version_mismatch, :db_update_failed
      end
    render status: status_code, json: poh.results.to_json
  end

  private

  # strong params / whitelist params
  def poh_params
    params.permit(:druid, :incoming_version, :incoming_size, :storage_location, :checksums_validated)
  end

  def bare_druid
    poh_params[:druid]&.split(':', 2)&.last
  end

  def incoming_version
    poh_params[:incoming_version]&.to_i
  end

  def incoming_size
    poh_params[:incoming_size]&.to_i
  end

  def moab_storage_root
    return unless poh_params[:storage_location]
    MoabStorageRoot.find_by(storage_location: "#{poh_params[:storage_location]}/#{Moab::Config.storage_trunk}")
  end

  # @return boolean
  def checksums_validated
    return poh_params[:checksums_validated].casecmp('true').zero? if poh_params[:checksums_validated]
    false
  end
end
