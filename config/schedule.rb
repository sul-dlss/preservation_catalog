# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

# run these task only on servers with the correct roles in Capistrano
# these tasks append to existing logs
every '0 5 1-7 * 6', roles: [:m2c] do
  set :output, standard: 'log/m2c.log', error: 'log/m2c-err.log'
  rake 'm2c_exist_all_storage_roots'
end
every '0 5 15-21 * 6', roles: [:m2c] do
  set :output, standard: 'log/m2c.log', error: 'log/m2c-err.log'
  rake 'm2c_exist_all_storage_roots'
end

every '0 5 8-14 * 6', roles: [:c2m] do
  set :output, standard: 'log/c2m.log', error: 'log/c2m-err.log'
  rake "c2m_check_version_all_dirs[`date --date='7 days ago' --iso-8601=s`]"
end
every '0 5 22-28 * 6', roles: [:c2m] do
  set :output, standard: 'log/c2m.log', error: 'log/c2m-err.log'
  rake "c2m_check_version_all_dirs[`date --date='7 days ago' --iso-8601=s`]"
end
