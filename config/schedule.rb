# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

# these append to existing logs
every :tuesday, roles: [:queue_populator] do
  set :output, standard: nil, error: 'log/m2c-err.log'
  runner 'MoabStorageRoot.find_each(&:m2c_check!)'
end
every :wednesday, roles: [:queue_populator] do
  set :output, standard: nil, error: 'log/c2a-err.log'
  runner 'CompleteMoab.archive_check_expired.find_each(&:audit_moab_version_replication!)'
end
every :friday, roles: [:queue_populator] do
  set :output, standard: nil, error: 'log/c2m-err.log'
  runner 'MoabStorageRoot.find_each(&:c2m_check!)'
end
every :sunday, at: '1am', roles: [:queue_populator] do
  set :output, standard: nil, error: 'log/cv-err.log'
  runner 'MoabStorageRoot.find_each(&:validate_expired_checksums!)'
end

every :hour, roles: [:cache_cleaner] do
  set :output, standard: '/var/log/preservation_catalog/zip_cache_cleanup.log'
  command <<-'END_OF_COMMAND'
    find /sdr-transfers -mindepth 5 -type f -name "*.zip" -mtime +1 -exec bash -c 'TARGET="{}"; rm -v ${TARGET%ip}*' \;
  END_OF_COMMAND
end

every :day, at: '1:15am', roles: [:cache_cleaner] do
  set :output, standard: '/var/log/preservation_catalog/zip_cache_cleanup.log'
  command <<-'END_OF_COMMAND'
    find /sdr-transfers/ -not -path "*/\.*" -type d -empty -delete
  END_OF_COMMAND
end
