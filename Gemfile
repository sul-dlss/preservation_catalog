source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

# general Ruby/Rails gems
gem 'aws-sdk-s3', '~> 1.17'
gem 'committee' # Validates HTTP requests/responses per OpenAPI specification
gem 'config' # Settings to manage configs on different instances
gem 'dor-services-client', '~> 4.13'
gem 'dor-workflow-client', '~> 3.8' # audit errors are reported to the workflow service
gem 'honeybadger' # for error reporting / tracking / notifications
gem 'jbuilder', '~> 2.5' # Build JSON APIs with ease.
gem 'jwt' # for gating programmatic access to the application
gem 'okcomputer' # ReST endpoint with upness status
gem 'pg' # postgres database
gem "factory_bot_rails", "~> 4.0"
gem 'postgresql_cursor' # for paging over large result sets efficiently
# pry is useful for debugging, even in prod
gem 'pry-byebug' # call 'binding.pry' anywhere in the code to stop execution and get a pry-byebug console
gem 'pry-rails' # use pry as the rails console shell instead of IRB
gem 'puma', '~> 3.12' # app server
gem 'rails', '~> 6.0.2'
gem 'resque', '~> 1.27'
gem 'resque-lock' # deduplication of worker queue jobs
gem 'resque-pool'
gem 'ruby-prof' # to profile methods
gem 'whenever' # manage cron for audit checks

# Stanford gems
gem 'moab-versioning' # work with Moab Objects
gem 'druid-tools' # for druid validation and druid-tree parsing

group :development, :test do
  gem 'rspec-rails', '~> 3.6'
  gem 'rails-controller-testing'
  # Ruby static code analyzer http://rubocop.readthedocs.io/en/latest/
  gem 'rubocop', '~> 0.73.0'
  gem 'rubocop-rspec'
  # Codeclimate is not compatible with 0.18+. See https://github.com/codeclimate/test-reporter/issues/413
  gem 'simplecov', '~> 0.17.1'
  gem 'webmock'
end

group :development do
  gem 'listen', '>= 3.0.5', '< 3.2'
  gem 'hirb' # for db table display via rails console
end

group :test do
  gem 'shoulda-matchers', git: 'https://github.com/thoughtbot/shoulda-matchers.git', branch: 'rails-5'
end

group :deploy do
  gem 'capistrano-rails'
  gem 'capistrano-passenger'
  gem 'dlss-capistrano'
  gem 'capistrano-resque-pool'
end
