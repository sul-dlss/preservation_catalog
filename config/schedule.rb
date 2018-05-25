# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

# run this task only on servers with the :m2c role in Capistrano
every '0 5 1-7,15-21 * Sat', roles: [:m2c] do
  # append to existing logs
  set :output, standard: 'log/m2c.log', error: 'log/m2c-err.log'
  rake 'm2c_exist_all_storage_roots'
end

# run this task only on servers with the :c2m role in Capistrano
every '0 5 8-14,22-28 * Sat', roles: [:c2m] do
  # append to existing logs
  set :output, standard: 'log/c2m.log', error: 'log/c2m-err.log'
  rake "c2m_check_version_all_dirs[`date --date='7 days ago' --iso-8601=s`]"
end
