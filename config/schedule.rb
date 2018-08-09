# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

# these append to existing logs
every :tuesday, roles: [:m2c] do
  set :output, standard: nil, error: 'log/m2c-err.log'
  runner 'MoabStorageRoot.find_each(&:m2c_check!)'
end
every :friday, roles: [:c2m] do
  set :output, standard: nil, error: 'log/c2m-err.log'
  runner 'MoabStorageRoot.find_each(&:c2m_check!)'
end
every :sunday, at: '1am', roles: [:cv] do
  set :output, standard: nil, error: 'log/cv-err.log'
  runner 'Audit::Checksum.validate_disk_all_storage_roots'
end

every :hour, roles: [:cache_cleaner] do
  set :output, standard: 'log/zip_cache_cleanup.log'
  command <<-'END_OF_COMMAND'
    find /sdr-transfers -mindepth 5 -type f -name "*.zip" -mtime +1 -exec bash -c 'TARGET="{}"; rm -v ${TARGET%ip}*' \;
  END_OF_COMMAND
end
