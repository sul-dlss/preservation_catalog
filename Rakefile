# frozen_string_literal: true

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative 'config/application'
Rails.application.load_tasks

require 'rubocop/rake_task'
RuboCop::RakeTask.new

desc 'Run erblint against ERB files'
task erblint: :environment do
  puts 'Running erblint...'
  system('bundle exec erblint --lint-all --format compact')
end

desc 'Run all configured linters'
task lint: %i[rubocop erblint]

# clear the default task injected by rspec
task(:default).clear

task default: [:lint, :spec]
