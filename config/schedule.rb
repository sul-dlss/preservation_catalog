# frozen_string_literal: true

# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

require 'config'

Config.load_and_set_settings(Config.setting_files('config', 'production'))

# these cron jobs all append to existing log files

# These define jobs that checkin with Honeybadger.
# If changing the schedule of one of these jobs, also update at https://app.honeybadger.io/projects/54415/check_ins
job_type :rake, "cd :path && :environment_variable=:environment bundle exec rake :task --silent :output && curl 'https://api.honeybadger.io/v1/check_in/:check_in"
job_type :runner_hb, "cd :path && bin/rails runner -e :environment ':task' && curl 'https://api.honeybadger.io/v1/check_in/:check_in' :output"

# 11 am on the 1st of every month
# If changing schedule, also change for HB checkin
every :month, at: '11:00', roles: [:queue_populator] do
  set :output, standard: nil, error: 'log/m2c-err.log'
  set :check_in, Settings.honeybadger_checkins.moab_to_catalog
  runner_hb 'MoabStorageRoot.find_each(&:m2c_check!)'
end

# 11 am on the 15th of every month - the 'whenever' syntax for this is awkward and needs an ignored month
# for the day to get parsed, so just use raw cron syntax
every '0 11 15 * *', roles: [:queue_populator] do
  set :output, standard: nil, error: 'log/c2m-err.log'
  set :check_in, Settings.honeybadger_checkins.catalog_to_moab
  runner_hb 'MoabStorageRoot.find_each(&:c2m_check!)'
end

# Proactivily audit to spread out load.
# Any that are not validated but hit fixity TTL will be validated by weekly audit below.
every :day, at: '8pm', roles: [:queue_populator] do
  set :output, standard: nil, error: 'log/c2a-err.log'
  runner 'PreservedObject.order(last_archive_audit: :asc).limit(PreservedObject.daily_check_count).find_each(&:audit_moab_version_replication!)'
end

every :wednesday, roles: [:queue_populator] do
  set :output, standard: nil, error: 'log/c2a-err.log'
  set :check_in, Settings.honeybadger_checkins.audit_replication
  runner_hb 'PreservedObject.archive_check_expired.find_each(&:audit_moab_version_replication!)'
end

# Proactivily validate to spread out load.
# Any that are not validated but hit fixity TTL will be validated by weekly validation below.
every :day, at: '10pm', roles: [:queue_populator] do
  set :output, standard: nil, error: 'log/cv-err.log'
  runner 'CompleteMoab.order(last_checksum_validation: :asc).limit(CompleteMoab.daily_check_count).find_each(&:validate_checksums!)'
end

every :sunday, at: '1am', roles: [:queue_populator] do
  set :output, standard: nil, error: 'log/cv-err.log'
  set :check_in, Settings.honeybadger_checkins.checksum_validation
  runner_hb 'MoabStorageRoot.find_each(&:validate_expired_checksums!)'
end

every :hour, roles: [:cache_cleaner] do
  set :output, standard: '/var/log/preservation_catalog/zip_cache_cleanup.log'
  rake 'prescat:cache_cleaner:stale_files'
end

every :day, at: '1:15am', roles: [:cache_cleaner] do
  set :output, standard: '/var/log/preservation_catalog/zip_cache_cleanup.log'
  rake 'prescat:cache_cleaner:empty_directories'
end
