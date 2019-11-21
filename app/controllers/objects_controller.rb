# frozen_string_literal: true

require 'csv'

##
# ObjectsController allows consumers to interact with preserved objects
#  (Note: methods will eventually be ported from sdr-services-app)
class ObjectsController < ApplicationController
  # return the PreservedObject model for the druid (supplied with druid: prefix)
  # GET /objects/:druid
  def show
    render json: PreservedObject.find_by!(druid: druid).to_json
  end

  def manifest
    params[:type] = 'manifest'
    params[:filepath] ||= 'signatureCatalog.xml'
    file_content = MoabStorageService.retrieve_file(druid, 'manifest', params[:filepath], params[:version])
    render xml: file_content, status: :ok
  end

  def metadata
    file_content = MoabStorageService.retrieve_file(druid, params[:metadata], params[:filepath], params[:version])
    render xml: file_content, status: :ok
  end

  def content
    file_content = MoabStorageService.retrieve_file(druid, 'content', params[:filepath], params[:version])
    # plain? body? file?
    render body: file_content, status: :ok
  end

  # return a specific file from the Moab
  # GET /objects/:druid/file?type=manifest&filepath=signatureCatalog.xml
  def file
    err_msgs = file_params_errors(params)
    if err_msgs.present?
      render(plain: "400 Bad Request: #{err_msgs.join('; ')}", status: :bad_request)
      return
    end

    file_content = MoabStorageService.retrieve_file(druid, params[:type], params[:filepath], params[:version])
    render plain: file_content, status: :ok
  rescue Moab::MoabRuntimeError => e
    render(plain: "404 Not Found: #{e}", status: :not_found)
  end

  # return the checksums and filesize for a single druid (supplied with druid: prefix)
  # GET /objects/:druid/checksum
  def checksum
    render json: content_files_checksums(druid).to_json
  end

  # return the checksums and filesize for a list of druids (supplied with druid: prefix)
  # note: this is deliberately allowed to be a POST to allow for a large number of druids to be passed in
  # GET OR POST /objects/checksums?druids[]=druid1&druids[]=druid2&druids[]=druid3
  def checksums
    unless druids.present?
      render(plain: "400 bad request - druids param must be populated", status: :bad_request)
      return
    end

    respond_to do |format|
      format.json do
        render json: json_checksum_list
      end
      format.csv do
        render plain: csv_checksum_list
      end
      format.any { render status: :not_acceptable, plain: 'Format not acceptable' }
    end
  end

  private

  def druid
    strip_druid(params[:id])
  end

  def druids
    return [] unless params[:druids].present?
    params[:druids].map { |druid| strip_druid(druid) }.sort.uniq # normalize, then sort, then de-dupe
  end

  def file_params_errors(params)
    err_msgs = []
    err_msgs << 'type param must be one of manifest, metadata, content' unless ['manifest', 'metadata', 'content'].include?(params[:type])
    err_msgs << 'filepath param must be populated' if params[:filepath].blank?

    if params[:version]
      if params[:version].match?(/^[1-9]\d*$/)
        params[:version] = params[:version].to_i
      else
        err_msgs << 'version param must be a positive integer'
      end
    end
    err_msgs
  end

  def return_bare_druids?
    params[:return_bare_druids] == 'true'
  end

  def returned_druid(druid)
    return_bare_druids? ? druid.to_s : "druid:#{druid}"
  end

  def json_checksum_list
    druids.map { |druid| { returned_druid(druid) => content_files_checksums(druid) } }.to_json
  end

  def csv_checksum_list
    CSV.generate do |csv|
      druids.each do |druid|
        content_files_checksums(druid).each do |checksum|
          csv << [returned_druid(druid), checksum[:filename], checksum[:md5], checksum[:sha1], checksum[:sha256], checksum[:filesize]]
        end
      end
    end
  end

  def content_files_checksums(druid)
    content_group = MoabStorageService.retrieve_content_file_group(druid)
    content_group.path_hash.map do |file, signature|
      { filename: file, md5: signature.md5, sha1: signature.sha1, sha256: signature.sha256, filesize: signature.size }
    end
  end
end
