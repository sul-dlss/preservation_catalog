require_relative 'boot'

require 'rails/all'

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
  end
end

require 'moab'
Moab::Config.configure do
  # FIXME: put this hardcoded dir in settings.yml file (github issue #21)
  storage_roots File.join(File.dirname(__FILE__), '..', 'spec','fixtures')
  storage_trunk 'moab_storage_root'
end
