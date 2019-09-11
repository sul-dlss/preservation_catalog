# frozen_string_literal: true

require 'csv'

##
# ObjectsController allows consumers to interact with preserved objects
#  (Note: methods will eventually be ported from sdr-services-app)
class ObjectsController < ApplicationController
  # return the PreservedObject model for the druid (supplied with druid: prefix)
  # GET /objects/:druid
  def show
    object = PreservedObject.find_by!(druid: strip_druid(params[:id]))
    render json: object.to_json
  end

  # return the checksums and filesize for a single druid (supplied with druid: prefix)
  # GET /objects/:druid/checksum
  def checksum
    render json: checksum_for_object(params[:id]).to_json
  end

  # return the checksums and filesize for a list of druid (supplied with druid: prefix)
  # GET /objects/checksums?druids=druida,druidb,druidc
  def checksums
    druids = params[:druids]
    respond_to do |format|
      format.json do
        results = druids.map { |druid| { "#{druid}": checksum_for_object(druid) } }
        render json: results.to_json
      end
      format.csv do
        results = CSV.generate do |csv|
          druids.each do |druid|
            checksum_for_object(druid).each do |checksum|
              csv << [druid, checksum[:filename], checksum[:md5], checksum[:sha1], checksum[:sha256], checksum[:filesize]]
            end
          end
        end
        render plain: results
      end
      format.any  { render status: 406, plain: 'Format not acceptable' }
    end
  rescue NoMethodError => e
    render status: 500, json: e.message
  end

  private

  def checksum_for_object(druid)
    content_group = retrieve_file_group(druid)
    content_group.path_hash.map do |file, signature|
      { filename: file, md5: signature.md5, sha1: signature.sha1, sha256: signature.sha256, filesize: signature.size }
    end
  end

  def retrieve_file_group(druid)
    Moab::StorageServices.retrieve_file_group('content', druid)
  rescue StandardError => e
    refine_invalid_druid_error!(e)
  end
end
