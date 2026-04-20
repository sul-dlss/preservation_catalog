# frozen_string_literal: true

require_relative 'boot'

# Select only parts we need from rails/all
require 'rails'
require 'action_controller/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'action_cable/engine'

# Pick the frameworks you want:
# require 'action_view/railtie'

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
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.

    # Add timestamps to all loggers (both Rack-based ones and e.g. Sidekiq's)
    config.log_formatter = proc do |severity, datetime, _progname, msg|
      "[#{datetime.to_fs(:iso8601)}] [#{severity}] #{msg}\n"
    end

    # accept_request_filter omits OKComputer & Sidekiq routes
    accept_proc = proc { |request| request.path.start_with?('/v1') }
    config.middleware.use(
      Committee::Middleware::RequestValidation,
      schema_path: 'openapi.yml',
      strict: true,
      error_class: JSONAPIError,
      accept_request_filter: accept_proc,
      parse_response_by_content_type: false,
      query_hash_key: 'action_dispatch.request.query_parameters',
      strict_reference_validation: true,
      parameter_overwrite_by_rails_rule: false
    )

    config.middleware.use Committee::Middleware::ResponseValidation, schema_path: 'openapi.yml'

    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Double-output logging, both to Rails.logger and $stdout.  Helps avoid puts statements.
    # If you don't want that, just use Rails.logger (or another Logger instance)
    # @return [Logger]
    def self.logger
      @logger ||= ActiveSupport::BroadcastLogger.new(Logger.new($stdout))
    end
  end
end
