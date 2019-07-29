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

module PreservationCatalog
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.1

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Double-output logging, both to Rails.logger and STDOUT.  Helps avoid puts statements.
    # If you don't want that, just use Rails.logger (or another Logger instance)
    # @return [Logger]
    def self.logger
      @logger ||= Logger.new(STDOUT).extend(ActiveSupport::Logger.broadcast(Rails.logger))
    end
  end
end
