source 'https://rubygems.org'

# general Ruby/Rails gems
gem 'aws-sdk-s3', '~> 1.17'
gem 'committee' # Validates HTTP requests/responses per OpenAPI specification
gem 'config' # Settings to manage configs on different instances
gem 'dor-services-client', '~> 7.0' # avoid inadvertent cocina-models updates
gem 'dor-workflow-client', '~> 3.8' # audit errors are reported to the workflow service
gem 'honeybadger' # for error reporting / tracking / notifications
gem 'jbuilder', '~> 2.5' # Build JSON APIs with ease.
gem 'jwt' # for gating programmatic access to the application
gem 'lograge'
gem 'okcomputer' # ReST endpoint with upness status
gem 'pg' # postgres database
gem 'postgresql_cursor' # for paging over large result sets efficiently
# pry is useful for debugging, even in prod
gem 'pry-byebug' # call 'binding.pry' anywhere in the code to stop execution and get a pry-byebug console
gem 'pry-rails' # use pry as the rails console shell instead of IRB
gem 'puma', '~> 5.3' # app server
gem 'rails', '~> 6.1.0'
gem 'resque', '~> 1.27'
gem 'resque-pool'
gem 'whenever' # manage cron for audit checks

# Stanford gems
gem 'druid-tools' # for druid validation and druid-tree parsing
gem 'moab-versioning' # work with Moab Objects

group :development, :test do
  # Ruby static code analyzer https://rubocop.readthedocs.io/en/latest/
  gem 'rubocop', '~> 1.0'
  gem 'rubocop-rails'
  gem 'rubocop-rspec'
end

group :development do
  gem 'listen', '>= 3.0.5', '< 3.2'
end

group :test do
  gem 'factory_bot_rails', '~> 4.0'
  gem 'rails-controller-testing'
  gem 'rspec-rails', '~> 4.0'
  gem 'shoulda-matchers'
  # Codeclimate is not compatible with 0.18+. See https://github.com/codeclimate/test-reporter/issues/413
  gem 'simplecov', '~> 0.17.1'
  gem 'webmock'
end

group :deploy do
  gem 'capistrano-rails'
  gem 'capistrano-passenger'
  gem 'dlss-capistrano'
end
