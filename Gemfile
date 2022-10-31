source 'https://rubygems.org'

# general Ruby/Rails gems
gem 'aws-sdk-s3', '~> 1.17'
gem 'committee' # Validates HTTP requests/responses per OpenAPI specification
gem 'config' # Settings to manage configs on different instances
gem 'dor-event-client', '~> 1.0'
gem 'dor-workflow-client', '~> 5.0' # audit errors are reported to the workflow service
gem 'honeybadger' # for error reporting / tracking / notifications
gem 'jbuilder', '~> 2.5' # Build JSON APIs with ease.
gem 'jwt' # for gating programmatic access to the application
gem 'lograge'
gem 'okcomputer' # ReST endpoint with upness status
gem 'pg' # postgres database
gem 'postgresql_cursor' # for paging over large result sets efficiently
# pry is useful for debugging, even in prod
gem 'pry-byebug' # call 'binding.pry' anywhere in the code to stop execution and get a pry-byebug console
gem 'pry' # make it possible to use pry for IRB
gem 'puma', '~> 5.5' # app server
gem 'rails', '~> 7.0.0'
gem 'resque', '~> 1.27'
gem 'redis', '~> 4.0' # redis 5.x has breaking changes with resque, see https://github.com/resque/resque/issues/1821
gem 'resque-pool'
gem 'whenever' # manage cron for audit checks

# Stanford gems
gem 'druid-tools' # for druid validation and druid-tree parsing
gem 'moab-versioning', '~> 5.0' # work with Moab Objects

group :development, :test do
  gem 'rspec-rails', '~> 4.0'
  # Ruby static code analyzer https://rubocop.readthedocs.io/en/latest/
  gem 'rubocop', '~> 1.0'
  gem 'rubocop-rails'
  gem 'rubocop-rspec'
  gem 'rspec_junit_formatter' # used by CircleCI
end

group :development do
  gem 'listen', '~> 3.7'
end

group :test do
  gem 'factory_bot_rails', '~> 4.0'
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
