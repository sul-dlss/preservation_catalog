# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative 'config/application'
Rails.application.load_tasks

require 'rubocop/rake_task'
RuboCop::RakeTask.new

# clear the default task injected by rspec
task(:default).clear

task default: [:rubocop, :spec]
