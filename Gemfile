# frozen_string_literal: true

source 'https://rubygems.org'

gem 'aws-sdk-s3', '~> 1.208.0' # for S3 storage
gem 'bootsnap', require: false
gem 'committee' # Validates HTTP requests/responses per OpenAPI specification
gem 'config' # Settings to manage configs on different instances
gem 'connection_pool' # Used for redis
gem 'cssbundling-rails', '~> 1.4'
gem 'csv' # will be removed from standard library in Ruby 3.4
gem 'dor-event-client'
gem 'dor-services-client'
gem 'druid-tools' # for druid validation and druid-tree parsing
gem 'honeybadger' # for error reporting / tracking / notifications
gem 'importmap-rails'
gem 'jbuilder' # Build JSON APIs with ease.
gem 'jwt' # for gating programmatic access to the application
gem 'lograge'
gem 'moab-versioning', '~> 6.0' # work with Moab Objects
gem 'okcomputer' # ReST endpoint with upness status
gem 'pg' # postgres database
gem 'postgresql_cursor' # for paging over large result sets efficiently
gem 'propshaft' # asset pipeline
gem 'pry' # make it possible to use pry for IRB
gem 'pry-byebug' # call 'binding.pry' anywhere in the code to stop execution and get a pry-byebug console
gem 'puma' # app server
gem 'rails', '~> 8.0.0'
gem 'redis', '~> 5.0'
# The default Socket.getbyhostname and other libc-bound DNS resolutions in Ruby block the entire VM until they complete.
# In a single thread this doesn't matter, but it can cause competition and deadlock in multi-threaded environments.
# This library is included as part of Ruby to swap out the libc implementation for a thread-friendly pure ruby version.
# It is a monkey-patch, but obviously one provided and supported by the Ruby maintainers themselves.
gem 'resolv-replace'
gem 'sidekiq', '~> 8.0'
gem 'turbo-rails'
gem 'view_component'
gem 'whenever', require: false # Work around https://github.com/javan/whenever/issues/831

source 'https://gems.contribsys.com/' do
  gem 'sidekiq-pro'
end

group :development, :test do
  gem 'erb_lint', require: false
  # Ruby static code analyzer https://rubocop.readthedocs.io/en/latest/
  gem 'rubocop'
  gem 'rubocop-capybara'
  gem 'rubocop-factory_bot'
  gem 'rubocop-rails'
  gem 'rubocop-rspec'
  gem 'rubocop-rspec_rails'
  gem 'rspec-rails'
  gem 'rspec_junit_formatter' # used by CircleCI
end

group :development do
  gem 'listen', '~> 3'
end

group :test do
  gem 'capybara'
  gem 'debug'
  gem 'factory_bot_rails'
  gem 'rails-controller-testing'
  gem 'shoulda-matchers'
  gem 'simplecov'
  gem 'webmock'
end

group :deploy do
  gem 'capistrano-rails'
  gem 'capistrano-passenger'
  gem 'dlss-capistrano'
end
