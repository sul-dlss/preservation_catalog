# frozen_string_literal: true

##
# CatalogController allows consumers to interact with the Preservation Catalog, e.g.
# to add an existing moab object to the catalog, or to update an entry for a moab object
# that's already in the catalog.
class CatalogController < ApiController
  # POST /v1/catalog
  def create
    results = MoabRecordService::Create.execute(druid: bare_druid, incoming_version: incoming_version, incoming_size: incoming_size,
                                                moab_storage_root: moab_storage_root, checksums_validated: checksums_validated)
    status_code =
      if results.contains_result_code?(:created_new_object)
        :created # 201
      elsif results.contains_result_code?(:db_obj_already_exists)
        :conflict # 409
      elsif results.contains_result_code?(:invalid_arguments)
        :not_acceptable # 406
      else
        :internal_server_error # 500
      end
    render status: status_code, json: results.to_json
  end

  # PUT/PATCH /v1/catalog/:id
  # User can only update a partial record (application controls what can be updated)
  def update
    results = MoabRecordService::UpdateVersion.execute(druid: bare_druid, incoming_version: incoming_version, incoming_size: incoming_size,
                                                       moab_storage_root: moab_storage_root, checksums_validated: checksums_validated)
    status_code =
      if results.contains_result_code?(:actual_vers_gt_db_obj)
        :ok # 200
      elsif results.contains_result_code?(:db_obj_does_not_exist)
        :not_found # 404
      elsif results.contains_result_code?(:invalid_arguments)
        :not_acceptable # 406
      elsif results.contains_result_code?(:actual_vers_lt_db_obj)
        :bad_request # 400
      else
        :internal_server_error # 500 including  :unexpected_version, :db_versions_disagree, :db_update_failed
      end
    render status: status_code, json: results.to_json
  end

  private

  def bare_druid
    strip_druid(params[:druid])
  end

  def incoming_version
    params[:incoming_version]&.to_i
  end

  def incoming_size
    params[:incoming_size]&.to_i
  end

  def moab_storage_root
    return unless params[:storage_location]
    MoabStorageRoot.find_by(storage_location: "#{params[:storage_location]}/#{Moab::Config.storage_trunk}")
  end

  # @return boolean
  def checksums_validated
    case params[:checksums_validated]
    when TrueClass, FalseClass
      params[:checksums_validated]
    when String
      params[:checksums_validated].casecmp('true').zero?
    else
      false
    end
  end
end
