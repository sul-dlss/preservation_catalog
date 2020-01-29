# frozen_string_literal: true

require 'csv'

##
# ObjectsController allows consumers to interact with preserved objects
#  (Note: methods will eventually be ported from sdr-services-app)
class ObjectsController < ApplicationController
  # return the PreservedObject model for the druid (supplied with druid: prefix)
  # GET /v1/objects/:druid
  def show
    render json: PreservedObject.find_by!(druid: druid).to_json
  end

  # return a specific file from the Moab
  # GET /v1/objects/:druid/file?category=manifest&filepath=signatureCatalog.xml
  # useful params:
  # - category (content|manifest|metadata)
  # - filepath path of file, relative to category directory
  # - version (positive integer (as a string)) version of Moab
  def file
    if params[:version] && !params[:version].match?(/^[1-9]\d*$/)
      render(plain: "400 Bad Request: version parameter must be positive integer", status: :bad_request)
      return
    end

    obj_version = params[:version].to_i if params[:version]&.match?(/^[1-9]\d*$/)
    location = MoabStorageService.filepath(druid, params[:category], params[:filepath], obj_version)
    if location
      send_file location
    else
      render(plain: "404 File Not Found: #{druid}, #{params[:category]}, #{params[:filepath]}, #{params[:version]}", status: :not_found)
    end
  rescue ArgumentError => e
    render(plain: "400 Bad Request: #{e}", status: :bad_request)
  rescue Moab::MoabRuntimeError => e
    render(plain: "404 Not Found: #{e}", status: :not_found)
  end

  # return the checksums and filesize for a single druid (supplied with druid: prefix)
  # GET /v1/objects/:druid/checksum
  def checksum
    render json: content_files_checksums(druid).to_json
  end

  # return the checksums and filesize for a list of druids (supplied with druid: prefix)
  # note: this is deliberately allowed to be a POST to allow for a large number of druids to be passed in
  # GET OR POST /v1/objects/checksums?druids[]=druid1&druids[]=druid2&druids[]=druid3
  def checksums
    unless normalized_druids.present?
      render(plain: "400 Bad Request - druids param must be populated with valid druids", status: :bad_request)
      return
    end

    checksum_list, missing_druids, errored_druids = generate_checksum_list

    bad_recs_msg = "\nStorage object(s) not found for #{missing_druids.join(', ')}" if missing_druids.any?
    bad_recs_msg = (bad_recs_msg || '') + "\nProblems generating checksums for #{errored_druids.join(', ')}" if errored_druids.any?
    if bad_recs_msg.present?
      render(plain: "409 Conflict - #{bad_recs_msg}", status: :conflict)
      return
    end

    respond_to do |format|
      format.json do
        render json: checksum_list.to_json
      end
      format.csv do
        render plain: to_csv_checksum_list(checksum_list)
      end
      format.any { render status: :not_acceptable, plain: 'Format not acceptable' }
    end
  rescue Moab::InvalidSuriSyntaxError => e
    render(plain: "400 Bad Request: #{e}", status: :bad_request)
  end

  # Retrieves [Moab::FileInventoryDifference] from comparison of passed contentMetadata.xml
  #   with latest (or specified) version in Moab for all files (default) or a specified subset (shelve|preserve|publish)
  # Moab::FileInventoryDifference is returned as an XML response
  #
  # useful params:
  # - content_metadata  contentMetadata.xml to be compared against a version already in the Moab
  # - subset (default: 'all') which subset of files to compare (all|shelve|preserve|publish)
  # - version (positive integer (as a string)) version of Moab to be compared against (defaults to latest version)
  def content_diff
    if params[:version] && !params[:version].match?(/^[1-9]\d*$/)
      render(plain: "400 Bad Request: version parameter must be positive integer", status: :bad_request)
      return
    end
    obj_version = params[:version].to_i if params[:version]&.match?(/^[1-9]\d*$/)
    subset = params[:subset] ||= 'all'
    render(xml: MoabStorageService.content_diff(druid, params[:content_metadata], subset, obj_version).to_xml)
  rescue ArgumentError => e
    render(plain: "400 Bad Request: #{e}", status: :bad_request)
  rescue Moab::MoabRuntimeError => e
    render(plain: "500 Unable to get content diff: #{e}", status: :internal_server_error)
    Honeybadger.notify(e)
  end

  private

  def druid
    strip_druid(params[:id])
  end

  def normalized_druids
    return [] unless params[:druids].present?
    params[:druids].map { |druid| strip_druid(druid) }.sort.uniq # normalize, then sort, then de-dupe
  end

  def return_bare_druids?
    params[:return_bare_druids] == 'true'
  end

  def returned_druid(druid)
    return_bare_druids? ? druid.to_s : "druid:#{druid}"
  end

  def generate_checksum_list
    checksum_list = []
    missing_druids = []
    errored_druids = []
    normalized_druids.each do |druid|
      checksum_list << { returned_druid(druid) => content_files_checksums(druid) }
    rescue Moab::ObjectNotFoundException
      missing_druids << druid
    rescue Moab::InvalidSuriSyntaxError => e
      # this needs to raise 400 error
      raise e
    rescue StandardError => e
      errored_druids << "#{druid} (#{e.inspect})"
    end
    [checksum_list, missing_druids, errored_druids]
  end

  def to_csv_checksum_list(checksum_list)
    CSV.generate do |csv|
      checksum_list.each do |druid_checksum|
        druid_checksum.each do |druid, checksums|
          checksums.each do |checksum|
            csv << [druid, checksum[:filename], checksum[:md5], checksum[:sha1], checksum[:sha256], checksum[:filesize]]
          end
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
