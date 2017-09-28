require 'moab'
require 'moab/stanford'

Moab::Config.configure do
  storage_roots(Settings.moab.storage_roots.map { |_storage_root_name, storage_root_location| storage_root_location })
  storage_trunk(Settings.moab.storage_trunk)
end
