require 'faraday'
require 'retries'
# This class will send a put ReST call to the preservationWF via faraday. This also parses
# out a shorter error message, that only includes the moab validation error.
class WorkflowErrorsReporter

  def self.update_workflow(druid, error_message)
    error_message.select { |error| request(druid, 'moab-valid', moab_error(error)) if error.key?(PreservedObjectHandlerResults::INVALID_MOAB) }
  end

  def self.request(druid, process_name, error_message)
    return unless conn
    handler = proc do |exception, attempt_number, total_delay|
      Rails.logger.warn("Handler saw a #{exception.class}; retry attempt #{attempt_number}; #{total_delay} seconds have passed.")
    end
    with_retries(max_tries: 3, handler: handler, rescue: workflow_service_exceptions_to_catch) do
      @connection.put do |request|
        request.headers['content-type'] = "application/xml"
        request.url  "/workflow/dor/objects/druid:#{druid}/workflows/preservationWF/#{process_name}"
        request.body = "<process name='#{process_name}' status='error' errorMessage='#{error_message}'/>"
      end
    end
  rescue *workflow_service_exceptions_to_catch => e
    raise Faraday::Error, e
  end
  private_class_method def self.conn
    if Settings.workflow_services.url.present?
      @connection ||= Faraday.new(url: Settings.workflow_services.url) do |c|
        c.use Faraday::Response::RaiseError
        c.use Faraday::Adapter::NetHttp
      end
    else
      Rails.logger.warn('no workflow hookup - assume you are in test or dev environment')
    end
    @connection
  end
  private_class_method def self.workflow_service_exceptions_to_catch
    [Faraday::Error]
  end

  private_class_method def self.moab_error(error)
    /^.*\)(.*)$/.match(error[PreservedObjectHandlerResults::INVALID_MOAB]).captures.first
  end

end
