# frozen_string_literal: true

require_relative 'boot'

# Select only parts we need from rails/all
require 'rails'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'active_job/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

class JSONAPIError < Committee::ValidationError
  def error_body
    {
      errors: [
        { status: id, detail: message }
      ]
    }
  end

  def render
    [
      status,
      { 'Content-Type' => 'application/vnd.api+json' },
      [JSON.generate(error_body)]
    ]
  end
end

module PreservationCatalog
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # accept_request_filter omits OKComputer & Sidekiq routes
    accept_proc = proc { |request| request.path.start_with?('/v1') }
    config.middleware.use(
      Committee::Middleware::RequestValidation,
      schema_path: 'openapi.yml',
      strict: true,
      error_class: JSONAPIError,
      accept_request_filter: accept_proc,
      parse_response_by_content_type: false,
      query_hash_key: 'action_dispatch.request.query_parameters'
    )
    # TODO: we can uncomment this at a later date to ensure we are passing back
    #       valid responses. Currently, uncommenting this line causes 24 spec
    #       failures. See https://github.com/sul-dlss/preservation_catalog/issues/1407
    #
    # config.middleware.use Committee::Middleware::ResponseValidation, schema_path: 'openapi.yml'

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Double-output logging, both to Rails.logger and $stdout.  Helps avoid puts statements.
    # If you don't want that, just use Rails.logger (or another Logger instance)
    # @return [Logger]
    def self.logger
      @logger ||= Logger.new($stdout).extend(ActiveSupport::Logger.broadcast(Rails.logger))
    end
  end
end
