require 'faraday'
require 'retries'
# send errors to preservationWF workflow for an object via ReST calls.
class WorkflowErrorsReporter

  def self.update_workflow(druid, process_name, error_message)
    response = http_workflow_request(druid, process_name, error_message)
    if response
      if response.status == 204
        Rails.logger.debug("#{druid} - sent error to workflow service for preservationWF #{process_name}")
      else
        # Note: status == 400 will be handled by the rescue clause
        Rails.logger.warn("#{druid} - unable to update workflow: #{response.body}")
      end
    end
  rescue StandardError => e
    Rails.logger.warn("#{druid} - unable to update workflow #{e.inspect}")
  end

  private_class_method def self.http_workflow_request(druid, process_name, error_message)
    return unless conn
    handler = proc do |exception, attempt_number, total_delay|
      Rails.logger.debug("Handler saw a #{exception.class}; retry attempt #{attempt_number}; #{total_delay} seconds have passed.")
    end
    with_retries(max_tries: 3, handler: handler, rescue: Faraday::Error) do
      conn.put do |request|
        request.headers['content-type'] = "application/xml"
        request.url  "/workflow/dor/objects/druid:#{druid}/workflows/preservationWF/#{process_name}"
        request.body = "<process name='#{process_name} status='error' errorMessage='#{error_message}'/>"
      end
    end
  end

  private_class_method def self.conn
    if Settings.workflow_services_url.present?
      @connection ||= Faraday.new(url: Settings.workflow_services_url) do |c|
        c.use Faraday::Response::RaiseError
        c.use Faraday::Adapter::NetHttp
      end
    else
      Rails.logger.warn('no workflow hookup - assume you are in test or dev environment')
    end
  end
end
