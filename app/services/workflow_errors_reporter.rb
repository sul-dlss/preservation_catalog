require 'faraday'
# This class will send a put ReST call to the preservationWF via faraday. This also parses
# out a shorter error message, that only includes the moab validation error.
class WorkflowErrorsReporter

  def self.update_workflow(druid, error_message)
    error_message.select { |error| request(druid, 'moab-valid', moab_error(error)) if error.key?(PreservedObjectHandlerResults::INVALID_MOAB) }
  end

  private_class_method def self.conn
    @conn ||= Faraday.new(url: Settings.workflow_services.url)
  end

  private_class_method def self.request(druid, process_name, error_message)
    conn.put do |request|
      request.headers['content-type'] = "application/xml"
      request.url  "/workflow/dor/objects/druid:#{druid}/workflows/preservationWF/#{process_name}"
      request.body = "<process name='#{process_name}' status='error' errorMessage='#{error_message}'/>"
    end
  end

  private_class_method def self.moab_error(error)
    /^.*\)(.*)$/.match(error[PreservedObjectHandlerResults::INVALID_MOAB]).captures.first
  end

end
