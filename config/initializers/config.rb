# frozen_string_literal: true

Config.setup do |config|
  # Name of the constant exposing loaded settings
  config.const_name = 'Settings'
  config.env_prefix = 'SETTINGS'
  config.env_separator = '__'
  config.use_env = true
end
