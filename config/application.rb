require_relative 'boot'

# Select only parts we need from rails/all
require 'rails'
require 'active_record/railtie'
require 'action_controller/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module PreservationCoreCatalog
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.1

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    config.eager_load_paths += %W[#{config.root}/lib]
  end
end

require 'moab'
Moab::Config.configure do
  storage_roots File.join(File.dirname(__FILE__), '..', Settings.moab.storage_roots)
  storage_trunk Settings.moab.storage_trunk
end
