# frozen_string_literal: true

##
# ObjectsController allows consumers to interact with preserved objects
#  (Note: methods will eventually be ported from sdr-services-app)
class ObjectsController < ApplicationController
  # return the PreservedObject model for the druid (supplied with druid: prefix)
  # GET /objects/:druid
  def show
    object = PreservedObject.find_by(druid: strip_druid(params[:id]))
    if object
      render status: 200, json: object.to_json
    else
      render status: 404, json: 'Object not found'
    end
  end

  # return the checksums and filesize for a single druid (supplied with druid: prefix)
  # GET /objects/:druid/checksum
  def checksum
    content_group = Moab::StorageServices.retrieve_file_group('content', params[:id])
    results = content_group.path_hash.map do |file, signature|
      { filename: file, md5: signature.md5, sha1: signature.sha1, sha256: signature.sha256, filesize: signature.size }
    end
    render status: 200, json: results.to_json
  rescue Moab::ObjectNotFoundException
    render status: 404, json: 'Object not found'
  rescue StandardError => e
    render status: 500, json: e.message
  end

  # return the checksums and filesize for a list of druid (supplied with druid: prefix)
  # GET /objects/checksums?druids=druida,druidb,druidc
  def checksums
    # druids = params[:druids]
  end
end
