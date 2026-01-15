# frozen_string_literal: true

##
# ObjectsController allows consumers to interact with preserved objects
#  (Note: methods will eventually be ported from sdr-services-app)
class ObjectsController < ApiController
  before_action :set_preserved_object, only: %i[show ok]
  # return the PreservedObject model for the druid (supplied *without* `druid:` prefix)
  # GET /v1/objects/:id.json
  def show
    render json: @preserved_object.to_json
  end

  def ok
    render json: @preserved_object.moab_record.ok?.to_json
  end

  # queue a ValidateMoab job for a specific druid, typically called by a preservationIngestWF robot.
  #   This guarantees that we are testing the content on PresCat, not the content before it is transferred AND it also
  #   guarantees that, for the first time the robot step is run for a version, that we are checking the files on disk,
  #   and are NOT checking file that are not yet fully written to storage.
  #   In the past, checking the files within the pres-robots code was done before the files were fully flushed to disk,
  #   and thus failures were not caught.
  # GET /v1/objects/:id/validate_moab
  def validate_moab
    # ActiveJob::Base.perform_later will return an instance of the job if it was added to the
    # queue successfully. It will return false if the job was not enqueued.
    # The most likely cause is a temporary queue lock for the job and its specific payload, so
    # it is up to the caller to determine whether retrying later is appropriate.
    if ValidateMoabJob.perform_later(druid)
      render(plain: 'ok', status: :ok)
    else
      err_msg = "Failed to enqueue ValidateMoabJob for #{druid}. " \
                'The most likely cause is that the job was already enqueued and is waiting to be picked up. ' \
                'Retry later if appropriate.'
      render(plain: err_msg, status: :locked)
    end
  end

  # return a specific file from the Moab
  # GET /v1/objects/:id/file?category=manifest&filepath=signatureCatalog.xml
  # useful params:
  # - category (content|manifest|metadata)
  # - filepath path of file, relative to category directory
  # - version (positive integer (as a string)) version of Moab
  def file
    if params[:version] && !params[:version].match?(/^[1-9]\d*$/)
      render(plain: '400 Bad Request: version parameter must be positive integer', status: :bad_request)
      return
    end

    obj_version = params[:version].to_i if params[:version]&.match?(/^[1-9]\d*$/)
    location = MoabOnStorage::StorageServicesWrapper.filepath(druid, params[:category], params[:filepath], obj_version)
    if location
      send_file location
    else
      render(plain: "404 File Not Found: #{druid}, #{params[:category]}, #{params[:filepath]}, #{params[:version]}", status: :not_found)
    end
  rescue Moab::MoabRuntimeError => e
    render(plain: "404 Not Found: #{e}", status: :not_found)
  end

  # return the checksums and filesize for a single druid (supplied with druid: prefix)
  # GET /v1/objects/:id/checksum
  def checksum
    render json: content_files_checksums(druid).to_json
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
      render(plain: '400 Bad Request: version parameter must be positive integer', status: :bad_request)
      return
    end
    obj_version = params[:version].to_i if params[:version]&.match?(/^[1-9]\d*$/)
    subset = params[:subset] ||= 'all'
    render(xml: MoabOnStorage::StorageServicesWrapper.content_diff(druid, params[:content_metadata], subset, obj_version).to_xml)
  rescue Moab::MoabRuntimeError => e
    render(plain: "500 Unable to get content diff: #{e}", status: :internal_server_error)
    Honeybadger.notify(e)
  end

  private

  def druid
    strip_druid(params[:id])
  end

  def normalized_druids
    return [] if params[:druids].blank?
    params[:druids].map { |druid| strip_druid(druid) }.sort.uniq # normalize, then sort, then de-dupe
  end

  def return_bare_druids?
    params[:return_bare_druids] == 'true'
  end

  def returned_druid(druid)
    return_bare_druids? ? druid.to_s : "druid:#{druid}"
  end

  def content_files_checksums(druid)
    content_group = MoabOnStorage::StorageServicesWrapper.retrieve_content_file_group(druid)
    content_group.path_hash.map do |file, signature|
      { filename: file, md5: signature.md5, sha1: signature.sha1, sha256: signature.sha256, filesize: signature.size }
    end
  end

  def set_preserved_object
    @preserved_object = PreservedObject.find_by!(druid:)
  end
end
