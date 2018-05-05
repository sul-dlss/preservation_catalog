source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

# general Ruby/Rails gems
gem 'config' # Settings to manage configs on different instances
gem 'faraday' # ReST calls
gem 'honeybadger' # for error reporting / tracking / notifications
gem 'jbuilder', '~> 2.5' # Build JSON APIs with ease.
gem 'okcomputer'
gem 'pg' # postgres database
# pry is useful for debugging, even in prod
gem 'pry-byebug' # call 'binding.pry' anywhere in the code to stop execution and get a pry-byebug console
gem 'pry-rails' # use pry as the rails console shell instead of IRB
gem 'puma', '~> 3.7' # app server
gem 'rails', '~> 5.1.3'
gem 'resque', '~> 1.27'
gem 'resque-lock' # deduplication of worker queue jobs
gem 'retries' # robust handling of network glitches
gem 'ruby-prof' # to profile methods

# Stanford gems
gem 'moab-versioning' # work with Moab Objects
gem 'druid-tools' # for druid validation and druid-tree parsing

group :production do
  gem 'newrelic_rpm' # for production performance modeling
end

group :development, :test do
  gem 'rspec-rails', '~> 3.6'
  gem 'rails-controller-testing'
  gem 'coveralls'
  # Ruby static code analyzer http://rubocop.readthedocs.io/en/latest/
  gem 'rubocop', '~> 0.50.0' # avoid code churn due to rubocop changes
  gem 'rubocop-rspec'
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
end
