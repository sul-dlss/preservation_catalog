# frozen_string_literal: true

source 'https://rubygems.org'

gem 'aws-sdk-s3', '~> 1.208.0' # for S3 storage
gem 'bootsnap', require: false
gem 'committee' # Validates HTTP requests/responses per OpenAPI specification
gem 'config' # Settings to manage configs on different instances
gem 'mission_control-jobs' # web UI for SolidQueue at /queues
gem 'cssbundling-rails', '~> 1.4'
gem 'csv' # will be removed from standard library in Ruby 3.4
gem 'dor-event-client'
gem 'dor-services-client'
gem 'druid-tools' # for druid validation and druid-tree parsing
gem 'honeybadger' # for error reporting / tracking / notifications
gem 'importmap-rails'
gem 'jbuilder' # Build JSON APIs with ease.
gem 'jwt' # for gating programmatic access to the application
gem 'kaminari' # pagination
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
gem 'resolv-replace'
gem 'solid_queue'
gem 'turbo-rails'
gem 'view_component'

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
  gem 'shoulda-matchers'
  gem 'simplecov'
  gem 'webmock'
end

group :deploy do
  gem 'capistrano-rails'
  gem 'capistrano-passenger'
  gem 'dlss-capistrano'
end
