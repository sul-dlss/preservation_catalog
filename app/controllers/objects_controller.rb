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

  # return the checksums and filesize for a single druid (supplied with druid: prefix)
  # GET /objects/:druid/checksum
  def checksum
    render json: checksum_for_object(druid).to_json
  end

  # return the checksums and filesize for a list of druid (supplied with druid: prefix)
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
      format.any  { render status: :not_acceptable, plain: 'Format not acceptable' }
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

  def return_bare_druids?
    params[:return_bare_druids] == 'true'
  end

  def returned_druid(druid)
    return_bare_druids? ? druid.to_s : "druid:#{druid}"
  end

  def json_checksum_list
    druids.map { |druid| { returned_druid(druid) => checksum_for_object(druid) } }.to_json
  end

  def csv_checksum_list
    CSV.generate do |csv|
      druids.each do |druid|
        checksum_for_object(druid).each do |checksum|
          csv << [returned_druid(druid), checksum[:filename], checksum[:md5], checksum[:sha1], checksum[:sha256], checksum[:filesize]]
        end
      end
    end
  end

  def checksum_for_object(druid)
    content_group = MoabStorageService.retrieve_content_file_group(druid)
    content_group.path_hash.map do |file, signature|
      { filename: file, md5: signature.md5, sha1: signature.sha1, sha256: signature.sha256, filesize: signature.size }
    end
  end
end
