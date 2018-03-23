require 'moab'
require 'moab/stanford'

Moab::Config.configure do
  storage_roots(HostSettings.storage_roots.map { |_storage_root_name, storage_root_location| storage_root_location })
  storage_trunk(Settings.moab.storage_trunk)
  path_method(Settings.moab.path_method.to_sym)
end
